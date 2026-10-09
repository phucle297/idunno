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

- [ ] **RC-2.4-BASELINE:** tổ chức baseline nhóm 3–4 và sau đó 6–8 người theo [Milestone 2.4](docs/checklists/phase-2-human-playtest-and-core-feel.md#milestone-24--human-playtest-baseline); ghi build/hardware/network/input, nguyên nhân chết người chơi tự giải thích trước khi coaching, nhu cầu rematch tự nguyện, thời lượng và các chuỗi chaos lặp lại. Controller navigation/physical audio chỉ ghi đạt khi có thiết bị và đã thử.
- [ ] **RC-2.5-FEEL:** sau các sửa core feel, user thử bằng thiết bị thật để xác nhận phản hồi/comfort cải thiện; không suy ra từ test automation hoặc chỉnh tuning.
- [ ] **RC-2.6-FOLLOWUP:** chạy follow-up theo [Milestone 2.6](docs/checklists/phase-2-human-playtest-and-core-feel.md#milestone-26--follow-up-validation-and-phase-review); báo số death explanation đúng (mục tiêu ≥80%), người tự muốn rematch (đa số), ít nhất hai emergent patterns lặp lại và mọi lỗi control/session còn gặp. Chưa có phiên thì để unchecked.

## Cách báo kết quả

Mỗi lần kiểm tra gửi: `RC-ID — ngày/giờ — build client/server — số người/mạng — hardware/input/display — thao tác — kết quả — lỗi còn gặp — log/video nếu có`.

Không bắt buộc recording để công nhận báo cáo user, nhưng phải biết build và điều kiện đã thử. Agent ghi rõ evidence do user cung cấp, đối chiếu checklist/progress và chỉ đóng đúng gate được kiểm tra. Các phase tương lai chưa triển khai không có human acceptance được coi là passed.
