# Roam Control Regression Checklist

Use this checklist before packaging an IPA or declaring a development build stable. Test on the physical iPhone unless a row explicitly says the simulator is sufficient.

## Install and launch

- [ ] A clean install opens the four-page introduction.
- [ ] Introduction pages swipe and advance with Continue.
- [ ] The final page clearly shows the anonymous-statistics switch before setup completes.
- [ ] A clean install initially shows sharing disabled and sends nothing before affirmative opt-in.
- [ ] An existing installation preserves its previously saved sharing choice after updating.
- [ ] Set Up This iPhone opens Device Setup instead of dropping directly onto an unexplained map.
- [ ] An update install preserves pairing, favourites, history, appearance and map style.
- [ ] Settings shows the expected version, build and plausible built date/time.

## Pairing

- [ ] Pair This iPhone starts without crashing.
- [ ] The six-digit PIN is readable and accepted by iOS Settings.
- [ ] Successful pairing persists after relaunch.
- [ ] Import Existing File accepts a valid pairing record.
- [ ] An invalid record produces a readable error.
- [ ] Removing pairing requires confirmation and returns the app to Not paired.

## Map and search

- [ ] Live suggestions appear after two or more characters.
- [ ] Choosing a result dismisses the keyboard and clears the search text.
- [ ] Search accepts valid latitude/longitude coordinates.
- [ ] Invalid coordinates produce a readable error without changing location.
- [ ] Tapping the map drops a pin with one non-duplicated address description.
- [ ] Clear removes the selected pin/card state.
- [ ] Done dismisses the keyboard without covering the location card.
- [ ] The compass appears only when the map is rotated, tracks heading and returns north when tapped.
- [ ] Current location returns smoothly to the real position and north-up.

## Saved places

- [ ] Adding and removing a favourite updates immediately.
- [ ] A favourite can be renamed with a trailing swipe.
- [ ] Individual favourites and history rows can be deleted with a swipe.
- [ ] Clear Favourites and Clear History each require confirmation and affect only their own list.
- [ ] Choosing a saved place closes the list and selects it on the map.
- [ ] Resume Last Location works and its dismissal remains dismissed.

## Fixed location on Wi-Fi

- [ ] Before the first session attempt, copied diagnostics show location-task configuration `Not checked` and registration `Not attempted`.
- [ ] After a session reaches task submission, copied diagnostics show a matched permitted identifier and whether iOS accepted or rejected registration.
- [ ] Cancelling during connection cannot let an obsolete location-task callback start a replacement session.
- [ ] With LocalDevVPN connected, Start Location becomes active without mobile-data guidance.
- [ ] With LocalDevVPN disconnected, Roam Control opens it quickly and resumes automatically.
- [ ] Selecting another place and tapping Update Location changes the active location without restarting the flow.
- [ ] The active location persists while using another app.
- [ ] Stop & Restore requires confirmation, then restores the real location.
- [ ] The Dynamic Island activity has no accidental stop button.

## Fixed location on mobile data

- [ ] Roam Control opens LocalDevVPN when needed.
- [ ] Turn Mobile Data Off appears only for the mobile-data path.
- [ ] Turning mobile data off is detected automatically.
- [ ] Continue works as a manual fallback.
- [ ] Turn Mobile Data Back On appears only after the location session is active.
- [ ] The location remains active after 4G/5G is restored.
- [ ] An active location can be updated again without repeating startup.
- [ ] Stop restores the real location.

## Walking routes

- [ ] Preview Walking Route draws a plausible Apple Maps route.
- [ ] Distance uses yards/miles under UK regional settings.
- [ ] Pace changes update timing before the walk starts.
- [ ] Start Walking advances location along the route.
- [ ] Pause holds the current point and Resume continues from it.
- [ ] The walk continues while Apple Maps or another app is in front.
- [ ] Arrival holds the destination location.
- [ ] Walk Route Back reverses the journey.
- [ ] New Location allows a new destination without restoring the real location first.
- [ ] Stop & Restore requires confirmation and restores the real location.

## Recovery

- [ ] Force-closing during a fixed session shows interrupted-session recovery on relaunch.
- [ ] Resume Location reconnects to the saved location.
- [ ] Restore Real Location requires confirmation, clears the simulated location and leaves no new session active.
- [ ] Cancelling recovery restoration preserves the interrupted-session recovery options.
- [ ] Stop & Restore shows restoration progress for at least a moment before returning to Ready.
- [ ] My Real Location Is Already Back dismisses the recovery state.
- [ ] Force-closing during a walk offers Resume Walking from a recent saved point.
- [ ] Mobile-data recovery waits until data can be restored before finishing.

## Settings, diagnostics and reset

- [ ] Automatic, Light and Dark update the Settings screen immediately.
- [ ] Standard, Satellite and Hybrid update the map.
- [ ] Connection Health reports pairing, LocalDevVPN and location-session state accurately.
- [ ] Feedback links open the correct Bug Report and Feature Request forms.
- [ ] Share Diagnostics opens the iOS share sheet and contains no keys or PINs.
- [ ] About Roam Control describes the current controls and flows.
- [ ] Replay Introduction does not delete app data.
- [ ] Privacy shows the sharing toggle and the complete What Is Shared disclosure.
- [ ] Disabling sharing takes effect immediately and remains disabled after relaunch.
- [x] Existing telemetry test build: with sharing disabled, two relaunches produced no new self-hosted event (9 events, maximum ID 9 and unchanged latest timestamp before and after).
- [x] Build 56 SideStore-installed release candidate: with sharing explicitly disabled, force-close and relaunch produced no new self-hosted event; after sharing was enabled, participation and activation events were accepted by the self-hosted backend.
- [ ] Separately verify that no TelemetryDeck request is produced while sharing is disabled.
- [ ] Disabling sharing while requests are in progress cancels them where possible and no later action sends until sharing is enabled again.
- [ ] A failed first participation request is retried on the next activation.
- [ ] An app activation is counted when the app returns from the background, without a duplicate cold-launch event.
- [ ] A failed active-location update does not send an active-location-updated event.
- [ ] A build without any complete private analytics destination sends no requests.
- [ ] A self-hosted-only build sends only to the self-hosted endpoint; a TelemetryDeck-only build sends only to TelemetryDeck; a fully configured build sends to both.
- [ ] Usage events never contain coordinates, place names, searches, routes, pairing data or diagnostics.
- [ ] The built app contains `PrivacyInfo.xcprivacy` with tracking disabled.
- [ ] Reset Roam Control clears app data, returns to onboarding and does not alter LocalDevVPN.

## Accessibility and layout

- [ ] Normal text size retains the intended clean layout.
- [ ] Accessibility text sizes keep every primary control reachable by scrolling.
- [ ] Walking metrics and compact controls stack rather than clip at large sizes.
- [ ] VoiceOver gives meaningful names to icon-only buttons and status rows.
- [ ] Touch targets are comfortably usable.
- [ ] Reduce Motion removes nonessential map, card and onboarding animations.
- [ ] Light and dark appearances retain readable contrast.

## Final result

- [ ] No crash, hang or unexpected real-location restore occurred.
- [ ] No stale red error remained after a successful retry.
- [ ] Build succeeded in Release configuration.
- [ ] Version/build values match the planned package.
- [ ] Any known issue is recorded before distribution.

## 应用语言（仅显示层）

- 在设置的“语言”按钮中切换“跟随系统 / 简体中文 / English”，确认当前页面立即更新、重启后选择保留。
- 修改主题和地图样式后切换语言，确认这些偏好不变；收藏名称、收藏顺序、历史记录、配对记录均不变。
- 在地图选中地点并输入搜索文字后切换语言，确认地图选择、搜索文字和当前操作保留；自定义名称及地图服务提供的地点名称不被当作界面文案翻译。
- 在实体 iPhone 的固定位置、步行中及暂停状态下切换语言，确认连接不中断，位置、路线、步行速度和进度不变；更新位置、暂停/继续、停止并恢复仍正常。
- 检查引导、配对、内置 VPN、连接检查、恢复选项、更新提示、确认弹窗及辅助功能标签；中文长文案在大字体下应完整显示。
- 系统权限弹窗遵循 iOS 的应用/系统语言；许可证原文和复制的诊断报告保留原有内容。
- 运行 `python3 scripts/test-localization.py`，检查中文覆盖、英文原文、重复键、动态参数、语言保存及用户内容保留；再运行现有 `scripts/test-*.py` 回归检查。
