# Báo lỗi khi gặp thực tế

Theo yêu cầu user ngày2026-10-09, bỏ các checklist kiểm tra thủ công hiện tại và yêu cầu baseline/follow-up2.4–2.6 để tiếp tục phát triển. Đây là **waiver theo quyết định user**, không phải bằng chứng đã thực hiện hoặc pass những test chưa chạy. Không cần gửi báo cáo playtest hay hoàn thành checklist trước khi tiếp tục; user sẽ báo bug nếu gặp.

Phase5 validation follow-up đã [archive](docs/old-docs/phase-5-validation-followup/progress.json); Phase6 đang triển khai, Milestone6.1 đã hoàn thành profile/store, admission gắn identity và restart/isolation tích hợp với test tự động local. Tiếp theo là round participation6.2.1; chưa có reward/equip UI, chưa deploy; không thêm checklist user bắt buộc. [Archive Phase5](docs/old-docs/phase-5-session-distribution-and-release-readiness/progress.json), [Phase4](docs/old-docs/phase-4-disaster-remix-and-toy-town-interaction/progress.json), [Phase3](docs/old-docs/phase-3-player-caused-chaos/progress.json) và [Phase2](docs/old-docs/phase-2-human-playtest-and-core-feel/progress.json) giữ kết quả lịch sử; Phase2 vẫn hoãn. Kết luận "mọi gate đã pass" trong archive không áp dụng cho GPU thật, capture Windows mới hoặc human/network/audio acceptance chưa chạy. [Audit reconciliation](docs/old-docs/phase-5-validation-followup/decisions.md) ghi rõ correction; không sửa/xóa evidence cũ.

## Bản đã giao gần nhất

- Release mới: [Phase 5 Hardening Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-12-bd3b606), tải `DisasterParty-Windows-Internet-bd3b606.zip`, giải nén toàn bộ rồi chạy `DisasterParty.exe`. Client/server cùng revision `bd3b606971ce9cf5470e03c5945d229052eb5ddf`; endpoint: `https://server.permees.com`. Client cũ không tương thích.
- User đã duyệt **deploy và release** ngày2026-10-12. CI build/deploy pass; public smoke hai client Linux editor dùng đúng PCK pass HTTPS tickets/ENet/roster/Ready/Start/remote movement/owner transfer, RTT sample104ms. Cùng một orb/upstream, không phải native Windows/hai mạng riêng. Giữ nguyên cấu hình sức tải EC2; 20 client local pass không chứng minh sức tải production.
- Xác nhận cũ vẫn giữ: Windows `C:\Users\permees\Downloads\DisasterParty-public-0d10b28`, build `0d10b289520f43889dd19cf5beba9c2abbaaea92`. Không xác nhận package mới đã được tải/chạy trên máy user.
- Khi có bản mới, client/server cần matching. Bỏ checklist **không tự cho phép restart/deploy server hoặc đổi hạ tầng**; lần deploy/release này có user duyệt riêng, không đổi hạ tầng/capacity. Scope source/playtest hỗ trợ **20 người** (design capacity, automation-validated); kiểm tra người thật/Internet/audio dưới đây vẫn MỞ và automation không thay thế được.
- Xác nhận Internet/audio của bản trước do user cung cấp vẫn được giữ; không suy thành xác nhận cho mọi bản sau.
- Gói follow-up mới (local, **chưa deploy**): `.amp/in/artifacts/phase-5-followup-packages/` — `DisasterParty-Windows-62b69c8.zip`, `DisasterParty-Linux-server-62b69c8.tar.gz`, `PLAYTEST-NOTES.md`. Client/server cùng source revision `62b69c84802d5e79502b44d735df02f428a55e06`, PCK giống hệt; standalone Linux lifecycle pass, Windows native/GPU/audio/Internet chưa xác minh. Không dùng client mới với server public build cũ.
- Playtest Phase3 (chưa publish/deploy, dùng để user tự check): `.amp/in/artifacts/phase-3-packages/` — `DisasterParty-Windows-f82a5cb.zip` và `DisasterParty-Linux-server-f82a5cb.tar.gz`, cùng payload `DisasterParty.pck`; hướng dẫn điều khiển/ghi nhận bug nằm trong file `PLAYTEST-NOTES.md` kèm gói.

## Nếu gặp bug

Gửi ngắn: `build — thao tác — kết quả mong đợi — kết quả thực tế — số người/mạng — máy/độ phân giải — log/screenshot nếu có`.

Không bắt buộc recording hay mẫu báo cáo dài. Agent sẽ tái hiện, xác định owner, sửa và kiểm chứng theo bug được báo; chỉ thêm một mục kiểm tra có mục tiêu nếu fix thực sự cần user/device/network xác nhận.

## Kiểm tra cần thiết bị thật (không chặn bug report)

- **60FPS throughput trên GPU thật:** profile kịch bản 4 người + prop + chồng hazard của `tests/profile_overlap.gd` (720p/1080p, V-Sync off, p95 ≤ 16.67ms) trên máy có GPU/driver thật. Orb chỉ đo được llvmpipe (software rasterizer) nên không đưa ra claim throughput; pacing với V-Sync mặc định cũng cần màn hình vật lý (Xvfb không có vblank). Không cần làm trước khi báo bug.
- **Trạng thái performance:** số đo Phase3 p95 103/160ms trên llvmpipe không đạt 16.67ms; hoàn thành việc đo không phải pass mục tiêu. Cần profile matching build trên GPU thật, 120 warmup/600 samples ở cả 720p/1080p, ghi GPU/driver/build/map và p95. Chưa xác minh, không bị biến thành pass bởi waiver.
- **Capture trên Windows gốc:** các ảnh review phase cuối nằm trong `.amp/in/artifacts/phase-3-final/` được chụp trên Linux orb (llvmpipe). Muốn xác nhận giao diện đúng như bản Windows thì chạy build Windows và xem giúp các trạng thái: carry/prop, emote, shove cue, hazard chồng nhau, spectator/eliminated, rematch — chỉ cần báo khác biệt nếu thấy.
- **Matching build/network:** bản public mới là `bd3b606`, đã deploy và có exact-PCK public smoke; bản `0d10b28` giữ xác nhận lịch sử. Dùng Windows ZIP mới và kiểm tra revision trong BUILD.txt; ghi số người, máy/mạng, movement/owner departure/crash retry/audio. Một phòng 20 client loopback không chứng minh nhiều phòng 20 người trên EC2; public smoke một orb không thay thế phiên người thật ở hai mạng riêng. Không tự deploy/restart thêm để thực hiện check.

## Kiểm tra Phase4 cần người chơi thật (không chặn bug report)

Phase4 đã hoàn thành và archive (2026-10-11); các mục dưới đây vẫn MỞ cho đến khi có người chơi thật xác nhận — automation không thay thế được. Milestone 4.4 yêu cầu so sánh Normal/Hard với người thật. Agent đã đo bằng mô phỏng cùng seed và cùng tier (Normal chết sau 24.0s, Hard sau 21.0s ở cùng hazard lethality — Hard mạnh hơn chỉ nhờ nhịp độ, không nhân damage; cùng run, độ phân giải 0.5s), nhưng không thay thế cảm giác thật và không claim mục nào pass. Chơi 1–4 người, ghi theo format báo bug ngắn ở trên:

- **So sánh thời điểm chết Normal/Hard:** chọn preset trong lobby (PRESET), chơi cùng map vài hiệp mỗi chế độ, ghi thời gian sống sót. "Harder" không đồng nghĩa "tốt hơn" — báo nếu Hard thấy unfair, stun-lock hoặc ngược lại thấy chả khác gì.
- **Nhận diện nguyên nhân chết không cần hướng dẫn:** sau mỗi lần chết hỏi "vì sao?" — mong người chơi đọc được cause (Flood/Tornado/Meteor/Impact Debris/Burning Rubble/Earthquake/Lightning/Fire) từ cảnh báo và HUD mà không ai giải thích. Báo nếu cause khó hiểu.
- **Thử thoát hiểm:** trong lúc cảnh báo hỏi người chơi có thấy đường thoát/cao điểm không, có thử đi tới đó không; báo nếu cảnh báo không đủ rõ để quyết định (đặc biệt combo Fire+Earthquake với rubble cháy).
- **Tự nguyện chơi lại:** sau hiệp đầu hỏi có muốn rematch/chơi tiếp không và vì sao; record phản hồi ngược.
- **Thời lượng thực tế:** ghi thời lượng mỗi hiệp (target 8–12 phút; `match_duration` hiện 600s và configurable) kèm số người/mạng/máy.
