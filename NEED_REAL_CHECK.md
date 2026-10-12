# Báo lỗi khi gặp thực tế

Theo yêu cầu user ngày2026-10-09, bỏ các checklist kiểm tra thủ công hiện tại và yêu cầu baseline/follow-up2.4–2.6 để tiếp tục phát triển. Đây là **waiver theo quyết định user**, không phải bằng chứng đã thực hiện hoặc pass những test chưa chạy. Không cần gửi báo cáo playtest hay hoàn thành checklist trước khi tiếp tục; user sẽ báo bug nếu gặp.

`progress.json` giữ trạng thái Phase5 (mở nhưng chờ user chỉ đạo); [archive Phase4](docs/old-docs/phase-4-disaster-remix-and-toy-town-interaction/progress.json), [archive Phase3](docs/old-docs/phase-3-player-caused-chaos/progress.json) và [snapshot Phase2](docs/old-docs/phase-2-human-playtest-and-core-feel/progress.json) giữ toàn bộ kết quả đã chạy và failure chưa rõ nguyên nhân. Phase2 được hoãn, không đánh dấu hoàn thành; Phase3 và Phase4 hoàn thành với limitation/human gate mở được ghi nhận rõ bên dưới. Các bản cũ của checklist có trong Git; không xóa lịch sử test hoặc coi failure đã được sửa.

## Bản đã giao gần nhất

- Windows: `C:\Users\permees\Downloads\DisasterParty-public-0d10b28`.
- Build: `0d10b289520f43889dd19cf5beba9c2abbaaea92`; endpoint: `https://server.permees.com`.
- Khi có bản mới, client/server cần matching. Bỏ checklist **không cho phép restart/deploy server hoặc đổi hạ tầng** (vẫn cần user duyệt riêng; không làm trong turn này). Scope playtest hỗ trợ đã nâng lên **20 người** (design capacity, automation-validated) theo quyết định user 2026-10-12 "Your call"; kiểm tra người thật/Internet/audio dưới đây vẫn MỞ và automation không thay thế được.
- Xác nhận Internet/audio của bản trước do user cung cấp vẫn được giữ; không suy thành xác nhận cho mọi bản sau.
- Playtest Phase3 (chưa publish/deploy, dùng để user tự check): `.amp/in/artifacts/phase-3-packages/` — `DisasterParty-Windows-f82a5cb.zip` và `DisasterParty-Linux-server-f82a5cb.tar.gz`, cùng payload `DisasterParty.pck`; hướng dẫn điều khiển/ghi nhận bug nằm trong file `PLAYTEST-NOTES.md` kèm gói.

## Nếu gặp bug

Gửi ngắn: `build — thao tác — kết quả mong đợi — kết quả thực tế — số người/mạng — máy/độ phân giải — log/screenshot nếu có`.

Không bắt buộc recording hay mẫu báo cáo dài. Agent sẽ tái hiện, xác định owner, sửa và kiểm chứng theo bug được báo; chỉ thêm một mục kiểm tra có mục tiêu nếu fix thực sự cần user/device/network xác nhận.

## Kiểm tra cần thiết bị thật (không chặn bug report)

- **60FPS throughput trên GPU thật:** profile kịch bản 4 người + prop + chồng hazard của `tests/profile_overlap.gd` (720p/1080p, V-Sync off, p95 ≤ 16.67ms) trên máy có GPU/driver thật. Orb chỉ đo được llvmpipe (software rasterizer) nên không đưa ra claim throughput; pacing với V-Sync mặc định cũng cần màn hình vật lý (Xvfb không có vblank). Không cần làm trước khi báo bug.
- **Capture trên Windows gốc:** các ảnh review phase cuối nằm trong `.amp/in/artifacts/phase-3-final/` được chụp trên Linux orb (llvmpipe). Muốn xác nhận giao diện đúng như bản Windows thì chạy build Windows và xem giúp các trạng thái: carry/prop, emote, shove cue, hazard chồng nhau, spectator/eliminated, rematch — chỉ cần báo khác biệt nếu thấy.

## Kiểm tra Phase4 cần người chơi thật (không chặn bug report)

Phase4 đã hoàn thành và archive (2026-10-11); các mục dưới đây vẫn MỞ cho đến khi có người chơi thật xác nhận — automation không thay thế được. Milestone 4.4 yêu cầu so sánh Normal/Hard với người thật. Agent đã đo bằng mô phỏng cùng seed và cùng tier (Normal chết sau 24.0s, Hard sau 21.0s ở cùng hazard lethality — Hard mạnh hơn chỉ nhờ nhịp độ, không nhân damage; cùng run, độ phân giải 0.5s), nhưng không thay thế cảm giác thật và không claim mục nào pass. Chơi 1–4 người, ghi theo format báo bug ngắn ở trên:

- **So sánh thời điểm chết Normal/Hard:** chọn preset trong lobby (PRESET), chơi cùng map vài hiệp mỗi chế độ, ghi thời gian sống sót. "Harder" không đồng nghĩa "tốt hơn" — báo nếu Hard thấy unfair, stun-lock hoặc ngược lại thấy chả khác gì.
- **Nhận diện nguyên nhân chết không cần hướng dẫn:** sau mỗi lần chết hỏi "vì sao?" — mong người chơi đọc được cause (Flood/Tornado/Meteor/Impact Debris/Burning Rubble/Earthquake/Lightning/Fire) từ cảnh báo và HUD mà không ai giải thích. Báo nếu cause khó hiểu.
- **Thử thoát hiểm:** trong lúc cảnh báo hỏi người chơi có thấy đường thoát/cao điểm không, có thử đi tới đó không; báo nếu cảnh báo không đủ rõ để quyết định (đặc biệt combo Fire+Earthquake với rubble cháy).
- **Tự nguyện chơi lại:** sau hiệp đầu hỏi có muốn rematch/chơi tiếp không và vì sao; record phản hồi ngược.
- **Thời lượng thực tế:** ghi thời lượng mỗi hiệp (target 8–12 phút; `match_duration` hiện 600s và configurable) kèm số người/mạng/máy.
