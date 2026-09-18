# 内置本机 VPN（第一阶段）

Roam Control 内置的本机网络隧道基于 [LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN) / StosVPN，原作者包括 SideStore Team、Stossy11 和贡献者。原始许可证保存在 `Licensing/ThirdParty/LocalDevVPN-LICENSE.txt`，并随应用打包，可在内置 VPN 页面查看。

## 构建与签名

打开 `RoamControl.xcodeproj`，选择 `RoamControl` scheme。构建会同时生成 `RoamTunnel.appex` 并嵌入主应用的 `PlugIns` 目录，不需要安装第二个应用。

在 `Configuration/Local.private.xcconfig` 中配置自己的 `DEVELOPMENT_TEAM`；需要自定义 Bundle ID 时设置 `ROAMCONTROL_APP_BUNDLE_IDENTIFIER`。主应用与扩展的 Bundle ID 分别使用该值和该值加 `.RoamTunnel`，版本号需保持一致。不要单独修改主 target 的 Bundle ID，否则扩展 ID 将不匹配。

两个 target 都需要签名描述文件支持 Network Extension 的 `packet-tunnel-provider`；主应用还声明 `allow-vpn`。当前编译检查关闭了签名，不能据此确认免费账号、SideStore 或其他重签方式能够启动扩展。应先用实际签名账号在真机验证。

## 使用与验证

1. 按原流程完成本机配对。
2. 打开「设置 → Built-in Local VPN」，点击 Connect，允许添加 VPN 配置。
3. 状态为 Connected 后，点击 Check This iPhone Connection，确认配对服务可达。
4. 返回地图，启动固定定位或模拟步行。现有引擎继续访问 `10.7.0.1`。
5. 先停止定位并等待停止确认，再返回内置 VPN 页面断开。

固定接口为 `10.7.1.1/32`，目的路由为 `10.7.0.1/32`，默认互联网路由被排除。VPN 手动启动，不启用按需连接。服务只管理自身 provider ID 的配置，不主动停止或删除其他 VPN 配置；启用本机 VPN 时，系统仍可能影响其他 VPN 的连接状态。

定位启动及连接帮助统一使用内置 VPN，不再跳转独立 LocalDevVPN 应用。尚未配置时会自动创建 VPN 配置，首次使用需要授权。内置 VPN 连接失败会显示实际错误。

纯蜂窝网络下，连接本机 VPN 后会显示「Turn Mobile Data Off」。临时关闭移动数据并返回应用，现有服务发现流程会继续；仅在原生定位会话确认启动后显示「Turn Mobile Data Back On」，此时再恢复流量。Wi-Fi 下沿用原有发现及连接流程。取消待启动的定位会话会取消内置 VPN 启动等待，旧会话不会再次弹出移动数据引导。扩展保持运行不替代主应用原有后台保活。

## 真机回归清单

- 首次授权、拒绝授权、重新连接、重启应用后状态恢复。
- Wi-Fi 和蜂窝网络下服务发现、身份匹配、TCP 可达性。
- 无外部 LocalDevVPN 安装时完成固定定位和模拟步行。
- 后台、锁屏和网络切换时定位会话的行为。
- 恢复真实位置后断开 VPN，确认普通联网正常。
- 定位过程中内置 VPN 页面禁止断开；系统设置主动断开后的原有错误恢复。
- 使用自己的 Bundle ID 打包，确认主应用和扩展的签名、标识及版本匹配。
- 未安装外部 LocalDevVPN：纯流量启动时自动连接内置 VPN，按提示关闭流量，定位启动后恢复流量；固定定位和步行模拟分别验证。
- 已安装外部 LocalDevVPN 且从未配置内置 VPN：确认仍使用内置 VPN，不跳转外部应用。
- 内置 VPN 首次授权拒绝、启动等待中取消定位、取消后立即重新启动：确认没有旧会话提示或重复连接。

## 本地检查

运行 `python3 scripts/test-local-tunnel.py` 验证地址校验及 IPv4 包交换，`python3 scripts/test-embedded-vpn-startup.py` 使用生产路由方法和模拟 VPN 验证独立连接入口、蜂窝/Wi-Fi、无外部应用依赖、拒绝授权、取消及重复启动；原有 `scripts/test-*.py` 覆盖定位、后台与隐私回归。Xcode 可分别使用 iPhone 和 Simulator SDK 执行无签名构建，确认扩展打包和许可证资源。
