# Báo lỗi khi gặp thực tế

Theo yêu cầu user ngày2026-10-09, bỏ các checklist kiểm tra thủ công hiện tại và yêu cầu baseline/follow-up2.4–2.6 để tiếp tục phát triển. Đây là **waiver theo quyết định user**, không phải bằng chứng đã thực hiện hoặc pass những test chưa chạy. Không cần gửi báo cáo playtest hay hoàn thành checklist trước khi tiếp tục; user sẽ báo bug nếu gặp.

`progress.json` giữ trạng thái Phase3 và quyết định miễn acceptance; [snapshot Phase2](docs/old-docs/phase-2-human-playtest-and-core-feel/progress.json) giữ toàn bộ kết quả đã chạy và failure chưa rõ nguyên nhân. Phase2 được hoãn, không đánh dấu hoàn thành. Các bản cũ của checklist có trong Git; không xóa lịch sử test hoặc coi failure đã được sửa.

## Bản đã giao gần nhất

- Windows: `C:\Users\permees\Downloads\DisasterParty-public-0d10b28`.
- Build: `0d10b289520f43889dd19cf5beba9c2abbaaea92`; endpoint: `https://server.permees.com`.
- Khi có bản mới, client/server cần matching. Bỏ checklist không cho phép tăng capacity, restart/deploy server hoặc đổi hạ tầng. Scope playtest vẫn1–4 người.
- Xác nhận Internet/audio của bản trước do user cung cấp vẫn được giữ; không suy thành xác nhận cho mọi bản sau.

## Nếu gặp bug

Gửi ngắn: `build — thao tác — kết quả mong đợi — kết quả thực tế — số người/mạng — máy/độ phân giải — log/screenshot nếu có`.

Không bắt buộc recording hay mẫu báo cáo dài. Agent sẽ tái hiện, xác định owner, sửa và kiểm chứng theo bug được báo; chỉ thêm một mục kiểm tra có mục tiêu nếu fix thực sự cần user/device/network xác nhận.

## Kiểm tra cần thiết bị thật (không chặn bug report)

- **60FPS throughput trên GPU thật:** profile kịch bản 4 người + prop + chồng hazard của `tests/profile_overlap.gd` (720p/1080p, V-Sync off, p95 ≤ 16.67ms) trên máy có GPU/driver thật. Orb chỉ đo được llvmpipe (software rasterizer) nên không đưa ra claim throughput; pacing với V-Sync mặc định cũng cần màn hình vật lý (Xvfb không có vblank). Không cần làm trước khi báo bug.
- **Capture trên Windows gốc:** các ảnh review phase cuối nằm trong `.amp/in/artifacts/phase-3-final/` được chụp trên Linux orb (llvmpipe). Muốn xác nhận giao diện đúng như bản Windows thì chạy build Windows và xem giúp các trạng thái: carry/prop, emote, shove cue, hazard chồng nhau, spectator/eliminated, rematch — chỉ cần báo khác biệt nếu thấy.
