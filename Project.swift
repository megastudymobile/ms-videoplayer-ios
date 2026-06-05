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
            bundleId: "com.megastudyedu.videoplayer.example",
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
    ]
)
