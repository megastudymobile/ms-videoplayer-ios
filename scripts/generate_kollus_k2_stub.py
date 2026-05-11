#!/usr/bin/env python3
"""K2 stub Objective-C .m skeleton generator.

Reads KollusSDK public headers and produces a `.m` skeleton per class that
satisfies ADR-06 §K2 contract: each method sets an `NSError` out-param (when
applicable) and returns nil/NO/0. NSException is never raised.

The generated files are a first-pass skeleton. Manual review is expected
before integrating into the actual `libKollusSDK_stub.a` build.

Usage:
    python3 scripts/generate_kollus_k2_stub.py \
        --headers Vendor/KollusSDK/include/KollusSDK \
        --out Packaging/Kollus/Stub/Sources/KollusSDK
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

# Strip // and /* */ comments, respecting string literals.
def strip_comments(src: str) -> str:
    out = []
    i = 0
    n = len(src)
    in_str = False
    str_delim = ''
    while i < n:
        c = src[i]
        if in_str:
            out.append(c)
            if c == '\\' and i + 1 < n:
                out.append(src[i + 1])
                i += 2
                continue
            if c == str_delim:
                in_str = False
            i += 1
            continue
        if c == '"' or c == "'":
            in_str = True
            str_delim = c
            out.append(c)
            i += 1
            continue
        if c == '/' and i + 1 < n:
            nxt = src[i + 1]
            if nxt == '/':
                j = src.find('\n', i)
                if j == -1:
                    break
                i = j
                continue
            if nxt == '*':
                j = src.find('*/', i + 2)
                if j == -1:
                    break
                i = j + 2
                continue
        out.append(c)
        i += 1
    return ''.join(out)


INTERFACE_RE = re.compile(
    r'@interface\s+(\w+)\s*:\s*(\w+)\s*(?:<[^>]*>)?\s*(.*?)@end',
    re.DOTALL,
)

# Category: `@interface Foo (Bar)` — we skip these in the stub (main class stays primary)
CATEGORY_RE = re.compile(r'@interface\s+\w+\s*\(\s*\w*\s*\)', re.DOTALL)

# Extract method declarations: `- (RetType)selector...;` or `+ (RetType)...;`
METHOD_RE = re.compile(
    r'^[\t ]*([+\-])\s*\(\s*([^)]+)\s*\)\s*([^;]+);',
    re.MULTILINE,
)

# Property declarations to skip (they generate their own getters/setters)
PROPERTY_RE = re.compile(r'^[\t ]*@property', re.MULTILINE)


def extract_selector(declaration: str) -> str:
    """Extract the ObjC selector (name) from a method declaration body.

    `initWithMediaContentKey:(NSString*)mck` → `initWithMediaContentKey:`
    `prepareToPlayWithMode:(KollusPlayerType)type error:(NSError**)error` →
       `prepareToPlayWithMode:error:`
    `play` → `play`
    """
    # Remove newlines
    declaration = declaration.replace('\n', ' ').strip()
    # Tokenize on whitespace + type-annotation `(...)`
    parts = []
    i = 0
    n = len(declaration)
    while i < n:
        c = declaration[i]
        if c == '(':
            depth = 1
            i += 1
            while i < n and depth > 0:
                if declaration[i] == '(':
                    depth += 1
                elif declaration[i] == ')':
                    depth -= 1
                i += 1
            continue
        if c.isspace():
            i += 1
            continue
        # Accumulate identifier
        j = i
        while j < n and (declaration[j].isalnum() or declaration[j] == '_'):
            j += 1
        if j > i:
            token = declaration[i:j]
            parts.append(token)
            i = j
            # Is this a keyword (followed by `:`)?
            # Skip whitespace
            while i < n and declaration[i].isspace():
                i += 1
            if i < n and declaration[i] == ':':
                parts[-1] = token + ':'
                i += 1
                # Skip optional type `(...)` and param name
                while i < n and declaration[i].isspace():
                    i += 1
                if i < n and declaration[i] == '(':
                    depth = 1
                    i += 1
                    while i < n and depth > 0:
                        if declaration[i] == '(':
                            depth += 1
                        elif declaration[i] == ')':
                            depth -= 1
                        i += 1
                # Skip param name identifier
                while i < n and declaration[i].isspace():
                    i += 1
                while i < n and (declaration[i].isalnum() or declaration[i] == '_'):
                    i += 1
            continue
        i += 1
    # Selector is first token, plus all tokens ending with `:`
    if not parts:
        return ''
    selector = parts[0]
    if ':' in selector:
        # Multi-keyword selector
        return ''.join(p for p in parts if p.endswith(':'))
    return selector


def generate_body(ret_type: str, selector: str) -> str:
    """Generate method body per ADR-06 K2 rules."""
    ret = ret_type.strip().replace(' ', '')
    # Pointer types: NSString*, NSArray*, NSError**, id<Protocol>, etc.
    if ret == 'void':
        return (
            '    // K2 stub: simulator no-op\n'
            '    os_log_debug(OS_LOG_DEFAULT, "[KollusStub] %s called in simulator", __PRETTY_FUNCTION__);\n'
        )
    if ret == 'BOOL':
        if 'error:' in selector or '(NSError**)' in selector:
            return (
                '    if (error) {\n'
                '        *error = [NSError errorWithDomain:@"KollusStub"\n'
                '                                     code:-1\n'
                '                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];\n'
                '    }\n'
                '    return NO;\n'
            )
        return '    return NO;\n'
    if ret in ('NSInteger', 'NSUInteger', 'int', 'long', 'longlong', 'unsignedint', 'unsignedlong', 'float', 'double', 'CGFloat'):
        return '    return 0;\n'
    # Pointer / id / instancetype → nil
    if ret.endswith('*') or ret == 'id' or ret == 'instancetype' or ret.startswith('id<'):
        if 'error:' in selector:
            return (
                '    if (error) {\n'
                '        *error = [NSError errorWithDomain:@"KollusStub"\n'
                '                                     code:-1\n'
                '                                 userInfo:@{NSLocalizedDescriptionKey: @"Not available in simulator (K2 stub)"}];\n'
                '    }\n'
                '    return nil;\n'
            )
        return '    return nil;\n'
    # Struct / enum / typedef — best-effort zero init
    return f'    return ({ret_type}){{0}};\n'


def generate_implementation(class_name: str, super_class: str, body: str, header_name: str) -> str:
    # Strip property declarations - they don't need manual implementation
    body_no_props = PROPERTY_RE.sub('// @property (stub auto-synthesized)', body)

    methods = []
    for match in METHOD_RE.finditer(body):
        sigil = match.group(1)   # + or -
        ret_type = match.group(2).strip()
        decl_body = match.group(3).strip()
        selector = extract_selector(decl_body)
        if not selector:
            continue
        # Reconstruct the declaration as it appears in the header
        full_decl = f'{sigil} ({ret_type}){decl_body}'.strip()
        impl_body = generate_body(ret_type, selector)
        methods.append(f'{full_decl} {{\n{impl_body}}}\n')

    out = [
        f'// {class_name}.m\n',
        f'// K2 stub skeleton — regenerate with scripts/generate_kollus_k2_stub.py\n',
        f'// Reference header: {header_name}\n',
        f'// Per ADR-06: no NSException. Pointer return → nil, BOOL → NO, void → debug log.\n',
        '\n',
        '#import <os/log.h>\n',
        f'#import "{header_name}"\n',
        '\n',
        f'@implementation {class_name}\n',
        '\n',
    ]
    out.extend(methods)
    out.append('@end\n')
    return ''.join(out)


def process_header(path: Path, out_dir: Path) -> list[str]:
    raw = path.read_text(encoding='utf-8', errors='replace')
    stripped = strip_comments(raw)
    generated_files: list[str] = []
    # Iterate all @interface ... @end blocks.
    for match in INTERFACE_RE.finditer(stripped):
        class_name = match.group(1)
        super_class = match.group(2)
        interior = match.group(3)
        # Skip category blocks — interior may be empty but signature has parentheses
        header_slice = stripped[max(0, match.start() - 80): match.end()]
        if CATEGORY_RE.search(header_slice):
            continue
        impl = generate_implementation(class_name, super_class, interior, path.name)
        out_file = out_dir / f'{class_name}.m'
        out_file.write_text(impl, encoding='utf-8')
        generated_files.append(str(out_file))
    return generated_files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--headers', required=True, help='Kollus public header directory')
    parser.add_argument('--out', required=True, help='Output directory for generated .m files')
    args = parser.parse_args()

    headers_dir = Path(args.headers).resolve()
    out_dir = Path(args.out).resolve()

    if not headers_dir.is_dir():
        print(f'[ERROR] headers dir not found: {headers_dir}', file=sys.stderr)
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)

    all_generated: list[str] = []
    for header in sorted(headers_dir.glob('*.h')):
        generated = process_header(header, out_dir)
        for g in generated:
            all_generated.append(g)

    print(f'[OK] Generated {len(all_generated)} implementation file(s) in {out_dir}')
    for path in all_generated:
        print(f'  - {os.path.relpath(path, Path.cwd())}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
