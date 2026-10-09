# Các mục cần user kiểm tra thực tế

Đây là danh sách kiểm tra bằng người thật, thiết bị thật hoặc mạng thật; không phải lỗi đã được xác nhận. `progress.json` vẫn là nguồn trạng thái chính. Xem [checklist Phase 2](docs/checklists/phase-2-human-playtest-and-core-feel.md) để đối chiếu task/gate.

## Bản dùng để kiểm tra hiện tại

- Windows: `C:\Users\permees\Downloads\DisasterParty-public-0d10b28`.
- Build đầy đủ: `0d10b289520f43889dd19cf5beba9c2abbaaea92`; server tương ứng: `https://server.permees.com`.
- Tất cả người chơi phải dùng cùng build với server. Nếu có deployment mới, cập nhật bản kiểm tra trước khi tiếp tục; không trộn kết quả giữa các build.
- User đã xác nhận Internet và audio của bản trước hoạt động. Giữ bằng chứng đó; không yêu cầu kiểm tra lại chỉ vì thiếu recording. Các sửa movement/jump/death/airborne recovery mới cần xác nhận riêng trên bản tương ứng.

## Phase 2 — Kiểm tra ngay

### RC-2.2-MOVEMENT — Task 2.2.8c: điều khiển multiplayer

- [ ] Chơi 2 người trên Windows ở hai mạng Internet độc lập, không chỉ hai container hoặc hai cửa sổ cùng máy.
- [ ] Lặp lại với 4 người; ghi build, máy/GPU, độ phân giải, V-Sync, thiết bị input, mạng và RTT nếu đo được.
- [ ] Chạy thẳng, sprint, đổi hướng, dừng, xoay camera rồi ngừng input: không tự xoay liên tục, aim không bị kéo về góc cũ; ghi cảm giác phản hồi và giật/correction quan sát được.
- [ ] Nhảy, cầu thang và các đường lên/xuống thật trong Toy Town; kiểm tra overlap giữa người chơi (hiện không có player pushing).
- [ ] Bị knockdown/Earthquake khi còn sống, kể cả hồi phục trên không: model xuất hiện lại và chạy/sprint/nhảy tiếp được; ghi nếu có giật lớn lúc recovery. Automated fixture từng đo correction tối đa 0.9 m, chưa phải chấp nhận smoothness.
- [ ] Sau khi chết: không còn điều khiển invisible body; spectate và rematch khôi phục đúng nhân vật.

### RC-2.2-SESSION — Task 2.2.7: release-client session

- [ ] Create/Join bằng room ID trên các Windows PC/mạng riêng; ready/start, props, warnings, health/death/spectate/results nhất quán.
- [ ] Hoàn tất 5 rematch; owner rời phòng thì quyền chuyển đúng, owner mới tiếp tục được.
- [ ] Trong phiên có phối hợp với operator, kiểm tra mất server rồi tạo/join lại với ticket mới. Không tự restart shared server hoặc đổi firewall để thử nếu chưa được cho phép.
- [ ] Kiểm tra thực tế mouse release/recapture, pause/resume, lobby/results và disconnect recovery; không mất click/camera sau khi người chơi mới vào.

### RC-2.2-SETTINGS — Task 2.2.7: actual release EXE

- [ ] Mở `DisasterParty.exe` bình thường, thay settings bằng UI, thoát hẳn rồi mở lại; kiểm tra volume, sensitivity, accessibility và window/fullscreen được giữ đúng. Native editor/exact-PCK restart đã pass nhưng chưa thay thế bước actual release EXE này.
- [ ] Warning/effect audio nghe rõ trên thiết bị dùng trong phiên mới, không bị chồng âm che mất cảnh báo; ghi khác biệt nếu có. Audio baseline user xác nhận trước đó vẫn được công nhận.

### RC-2.3-DISPLAY — Thiết bị màn hình/input thực tế

- [ ] Nếu có nhiều màn hình khác DPI: chuyển game giữa các màn hình, resize/fullscreen rồi trở lại windowed; cửa sổ không mất title bar, UI không bị cắt và click đúng vị trí.
- [ ] Nếu `X connection to :0 broken` tái diễn trên WSL/X11: giữ log từ đầu lần chạy, lệnh launch, thời điểm display/process đóng và thao tác cuối cùng. Gửi bằng chứng để agent chẩn đoán; không tự kết luận audio/V-Sync là nguyên nhân. Không cần cố làm crash hoặc đánh dấu gate pass vì không tái hiện được.

## Phase 2 — Các phiên human playtest sau readiness

Chưa phải yêu cầu nâng capacity ngay: scope playtest hiện tại là 1–4 người. Nhóm 6–8 chỉ chạy khi prerequisites/capacity đã được chấp thuận và xác thực.

### RC-2.4-BASELINE — Ghi nhận gameplay trước khi chỉnh feel

**Trạng thái:** chờ người chơi thật; chưa có báo cáo baseline đủ build/điều kiện. Agent không thay bằng bot hoặc tự suy ra game vui từ regression. Có thể gộp phiên này với RC-2.2-MOVEMENT/SESSION để không bắt user thử hai lần; chỉ đóng mục thực sự đã quan sát. Bản baseline hiện dùng folder ở đầu tài liệu; chưa có bản mới trong đợt chuẩn bị này.

- [ ] Nhóm3–4 người trên Windows/mạng riêng: hướng tới3 round bình thường; ghi số người/round thực tế nếu thiếu người hoặc phải dừng. Không dùng demo/debug ép hazard/thắng cho kết quả baseline.
- [ ] Trước round đầu: ghi build client/server, ngày giờ, từng máy/GPU, resolution/DPI/V-Sync, chuột/controller, mạng/RTT nếu có và người đã biết chơi hay chưa. Mỗi người thử chạy/sprint/đổi hướng/nhảy,4 đường lên cao, cửa/chỗ trú, cầm/thả prop và camera trước khi bắt đầu.
- [ ] Sau mỗi lần chết, hỏi **trước khi giải thích**: “Bạn nghĩ chết vì gì? Có thấy/nghe cảnh báo không? Bạn đã định chạy đâu?” Ghi câu trả lời và nguyên nhân hiển thị; nếu nguyên nhân thực chưa rõ thì ghi chưa xác minh, không chấm đúng theo suy đoán.
- [ ] Cuối mỗi round: ghi thời lượng, người bị mất input/giật/stuck/camera che, thời gian spectate khó chịu nếu có; hỏi có muốn chơi tiếp không. Tách người tự muốn rematch khỏi round được yêu cầu để test.
- [ ] Ghi thời điểm và chuỗi ít nhất các tình huống đáng nhớ nếu xảy ra, ví dụ Flood→lên mái→Meteor→ngã/knockdown; ghi cả round không có tình huống vui. Không cần quay video; chỉ quay khi người tham gia đồng ý.
- [ ] Nhóm6–8: **đang chờ hỗ trợ capacity được phê duyệt và kiểm chứng**, không thực hiện trên server1–4 hiện tại chỉ để tick. Chưa đủ nhóm này thì gate đầy đủ2.4 vẫn mở; không tự tăng player cap/deploy.

Mẫu ngắn để gửi (lặp cho mỗi round/death):

```text
RC-2.4-BASELINE — ngày/giờ — build — số người/mạng — máy/input/display
Round: số | thời lượng | disconnect/input/camera/giật | tự muốn rematch: x/n
Death: thời điểm | nguyên nhân hiển thị/đã xác minh | người chơi tự giải thích
Warning: nhìn/nghe được? | đường thoát đã thử | thấy công bằng/khó hiểu ở đâu?
Moment: thời điểm | chuỗi sự kiện | có lặp ở round khác không?
Ưu tiên sửa theo người chơi: ...
```

### RC-2.5-FEEL — Xác nhận từng sửa có mục tiêu

**Agent làm sau baseline:** phân loại findings theo mức chặn chơi/tần suất/ảnh hưởng; tái hiện ở owner hiện có, sửa một vấn đề đã chứng minh và chạy regression/render trước/sau. User không phải chẩn đoán code. Chưa có findings baseline nên không đổi speed/camera/damage/pacing theo phỏng đoán; các fix movement/death đã giao thuộc2.2, không tự tính là kết quả2.5.

- [ ] Khi agent giao build/fix cụ thể: lặp đúng thao tác/route/hazard gây vấn đề với cùng điều kiện gần nhất; ghi bản trước và bản sau, tần suất trước/sau, cảm giác phản hồi/camera/warning và lỗi mới nếu có.
- [ ] Nếu fix thay đổi wire/build, tất cả người chơi và server phải matching. Chỉ thử Internet sau deployment được cho phép; không trộn bản hoặc yêu cầu user tự restart server.
- [ ] Chỉ xác nhận “cải thiện” cho tình huống thực sự đã thử. Nếu baseline không có vấn đề cần sửa, ghi bằng chứng và quyết định no-change riêng; không tạo một tuning để đánh dấu milestone xong.

### RC-2.6-FOLLOWUP — So sánh với baseline và quyết định đóng phase

**Trạng thái:** phụ thuộc baseline2.4 và kết quả xử lý2.5; chưa có follow-up để chấm. Dùng build đã giao sau fixes (hoặc cùng build nếu có quyết định no-change có bằng chứng), ghi version/điều kiện trước khi chơi.

- [ ] Lặp tình huống đã sửa rồi chơi round bình thường ở các nhóm đã đủ prerequisites; so với baseline cùng mẫu trên. Ghi số người/round thực tế, không ép round đạt8–12 phút; báo thời lượng thực so với mục tiêu.
- [ ] Death clarity: số lần người chơi tự giải thích đúng / tổng số death có nguyên nhân xác minh được; mục tiêu≥80%. Không có mẫu hoặc chưa xác minh nguyên nhân thì chưa đủ kết luận, không coi0/0 là đạt.
- [ ] Rematch: số người độc lập muốn chơi tiếp / tổng số được hỏi, phải là đa số trong mỗi nhóm; phân biệt với5 rematch do facilitator yêu cầu để regression.
- [ ] Emergence: ít nhất2 kiểu chuỗi sự kiện khác nhau lặp qua các round; gửi ví dụ/thời điểm, không tính2 lần cùng một chuỗi là2 kiểu.
- [ ] Không còn lỗi chặn phiên/điều khiển chưa xử lý. Nếu còn spinning, invisible living body, kẹt đường không thoát, mất click hoặc disconnect lặp, gửi bước tái hiện; agent quay lại2.5, chưa đóng phase.
- [ ] Nhóm6–8 chưa đủ hỗ trợ/thiết bị thì ghi blocked riêng; passing nhóm3–4 không thay thế gate cả hai nhóm.

## Các vấn đề cần xác nhận — không phải tất cả là lỗi hiện còn

| Mục | Bằng chứng hiện có | User cần kiểm tra / điều kiện |
| --- | --- | --- |
| Lag/tự xoay multiplayer | Cause yaw feedback đã sửa; prediction có synthetic latency/jitter/loss và native regression | RC-2.2-MOVEMENT trên matching build mới; quan sát aim khi thả input và giật khi đi/đổi hướng |
| Nhân vật vô hình sau knockdown/death | Các lỗi đã tái hiện, sửa, deploy; chưa có xác nhận gameplay mới từ user | Khi còn sống, hồi phục trên không rồi chạy/nhảy thấy model; sau chết không điều khiển body; rematch khôi phục |
| Recovery bị giật | Fixture từng đo correction tối đa0.9m; không phải kết luận mọi trận giật0.9m | Ghi cảm giác/thời điểm/RTT khi knockdown kết thúc, nhất là gần cầu thang/props |
| Owner không thấy round rematch | Recheck2026-10-09 có1 assertion owner fail; server/guest qua, isolated và full rerun không đổi code đều qua; cause chưa rõ | Trong RC-2.2-SESSION/2.4 ghi nếu bấm Rematch mà owner vẫn ở Results hoặc các máy lệch round; agent điều tra logs, user không cần tự tái tạo race |
| Model/địa hình/camera | Chưa có audit đầy đủ chuyển động và các route thật; không kết luận model hỏng từ source | Ghi clipping/tay-chân rời/đổi animation đột ngột, bước chân trượt, lối lên mái/kẹt cửa/camera che nếu gặp; agent tái hiện trước sửa |
| EXE không nhớ settings | Chưa được chứng minh là bug; editor/exact-PCK restart pass nhưng actual-EXE automation inconclusive | RC-2.2-SETTINGS: đổi bằng UI, thoát hẳn, mở lại và ghi giá trị; không cần redesign Settings |
| X11 display loss / mixed-DPI | X loss chưa tái hiện; physical mixed-monitor chưa thử | RC-2.3-DISPLAY khi có thiết bị hoặc lỗi tái diễn; không cần cố làm crash |

Các lỗi scale20 người, capacity lớn, hiện tượng Meteor/heartbeat từng thất bại rồi pass chưa rõ cause là phần agent phải điều tra nếu tái diễn/trước mở rộng; **không yêu cầu user chạy20 người hoặc tự sửa hạ tầng**. Giữ log lịch sử trong progress, không dùng checklist này để tuyên bố đã sửa.

## Cách báo kết quả

Mỗi lần kiểm tra gửi: `RC-ID — ngày/giờ — build client/server — số người/mạng — hardware/input/display — thao tác — kết quả — lỗi còn gặp — log/video nếu có`.

Không bắt buộc recording để công nhận báo cáo user, nhưng phải biết build và điều kiện đã thử. Agent ghi rõ evidence do user cung cấp, đối chiếu checklist/progress và chỉ đóng đúng gate được kiểm tra. Các phase tương lai chưa triển khai không có human acceptance được coi là passed.
