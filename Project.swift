import ProjectDescription

let project = Project(
    name: "VideoPlayerExample",
    organizationName: "megastudyedu",
    packages: [
        .local(path: ".")
    ],
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO"
        ]
    ),
    targets: [
        .target(
            name: "VideoPlayerExample",
            destinations: .iOS,
            product: .app,
            bundleId: "com.kollus.KollusPlayer",
            deploymentTargets: .iOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [
                    "UIColorName": "",
                    "UIImageName": ""
                ],
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [
                            [
                                "UISceneConfigurationName": "Default Configuration",
                                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                            ]
                        ]
                    ]
                ],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight"
                ],
                "UIBackgroundModes": [
                    "audio"
                ],
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true
                ]
            ]),
            sources: ["Example/Sources/**"],
            resources: ["Example/Resources/**"],
            dependencies: [
                .package(product: "VideoPlayerCore"),
                .package(product: "VideoPlayerShellSupport"),
                .package(product: "VideoPlayerEngineNative"),
                .package(product: "VideoPlayerEngineKollus"),
                .package(product: "VideoPlayerSkin")
            ]
        ),
        .target(
            name: "VideoPlayerExampleTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.megastudyedu.videoplayer.example.tests",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .default,
            sources: ["Example/Tests/**"],
            dependencies: [
                .target(name: "VideoPlayerExample")
            ]
        )
    ],
    schemes: [
        // 자동 생성 스킴 대신 명시 — QA용 보호 해제 플래그를 기본 비활성으로 등록한다.
        .scheme(
            name: "VideoPlayerExample",
            shared: true,
            buildAction: .buildAction(targets: ["VideoPlayerExample"]),
            testAction: .targets(["VideoPlayerExampleTests"]),
            runAction: .runAction(
                configuration: "Debug",
                executable: "VideoPlayerExample",
                arguments: .arguments(
                    launchArguments: [
                        .launchArgument(name: "-disableScreenshotProtection", isEnabled: false)
                    ]
                )
            )
        )
    ]
)
