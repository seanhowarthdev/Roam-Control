# 激活与在线授权

正式默认地址为 `https://ios.iirrll.top`，调试地址当前为 `http://192.168.110.119:18063`（Mac 的局域网地址与当前运行的真实后端）。真机和 Mac 需要位于同一局域网。真机的 `127.0.0.1` 指向手机自身，无法访问 Mac。

## 地址配置与发布

在 `Configuration/Local.private.xcconfig` 中覆盖 `CATGO_ACTIVATION_DEBUG_BASE_URL` 或 `CATGO_ACTIVATION_BASE_URL`，不带 `/api` 后缀：

```xcconfig
CATGO_ACTIVATION_DEBUG_BASE_URL = http:$(CATGO_URL_SLASH)$(CATGO_URL_SLASH)192.168.110.119:18063
CATGO_ACTIVATION_BASE_URL = https:$(CATGO_URL_SLASH)$(CATGO_URL_SLASH)ios.iirrll.top
```

Debug 使用调试地址与单独的 `RoamControl-Debug-Info.plist`，允许 HTTP 调试。Release 使用正式地址与原 `RoamControl-Info.plist`，没有 HTTP 放宽，代码也拒绝 HTTP 地址。发布前为正式域名配置 HTTPS 和后端代理，移除私有配置中的测试地址覆盖，使用 Release 构建。配置不放在用户设置页。

两个 Info.plist 除调试 ATS 项之外必须一致，测试会检查。Mac IP 改变后修改调试配置并重新构建。

## 用户流程

首次引导后进入设备设置，未激活时打开激活输入页面；成功后显示到期时间及服务器时区。用户可关闭页面查看地图或设置，但未通过授权不能配对、导入配对文件或启动/更新模拟定位。

设置与设备设置显示状态和到期时间，“激活与续费”可刷新状态、联系管理员及更换新码。续费由管理员修改当前码的最终到期时间完成，不换码、不接入支付。更换新码成功后才替换旧凭据，不叠加旧时间。

激活码只能兑换一次，换机需要新码。已激活设备恢复授权使用保存在设备专用 Keychain 的令牌在线验证。重置地图与配对设置不删除激活凭据，重置后仍需在线验证；清除设备钥匙串后需要新码。

## 在线限制

- 启动、回到前台、打开设置及使用配对/定位入口时验证，每 15 秒周期验证。
- 网络暂时不可用或发生连接、超时等网络错误时，仅保留尚未过期的原有短期授权，不延长或重新计时；没有有效授权时仍禁止使用。网络恢复立即在线重验，服务器拒绝或响应异常仍撤销授权。单次请求超时 8 秒。
- 每次在线验证只给最多 25 秒的短期授权；到期由服务器时间差计算，使用单调时钟计时，修改手机日期不能延长授权。
- 固定定位更新、步行每步更新、延迟启动的底层引擎都检查授权。失效后取消配对、停止模拟并执行原有真实定位恢复流程。
- iOS 暂停后台执行时无法保证固定验证周期；恢复执行时过期短期授权不能更新定位，回前台立即重验。
- 停止模拟及恢复真实定位始终允许。恢复失败仍使用现有诊断提示，不宣称恢复成功。

管理员联系方式由后端 `RENEWAL_CONTACT` 配置并随验证响应下发；未获取说明时显示通用联系提示。

## 验证

```sh
python3 scripts/test-activation.py
xcodebuild -project RoamControl.xcodeproj -scheme RoamControl -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build
```

真机验收：新码激活与重复激活提示；固定定位和步行期间断网、禁用或到期，确认停止；延长当前码时间并启用，刷新后恢复；换码失败保留旧凭据；失效时仍能停止模拟及恢复真实定位。VPN 路由、后台定位和设备恢复必须在真机验证。

模拟器运行时保留 Xcode 默认的临时签名，否则设备钥匙串可能不可用。仅编译验证的无签名 Release 构建不用于安装；真机安装使用自己的 Apple 签名配置。
