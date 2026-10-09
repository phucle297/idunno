# Báo lỗi khi gặp thực tế

Theo yêu cầu user ngày2026-10-09, bỏ các checklist kiểm tra thủ công hiện tại và yêu cầu baseline/follow-up2.4–2.6 để tiếp tục phát triển. Đây là **waiver theo quyết định user**, không phải bằng chứng đã thực hiện hoặc pass những test chưa chạy. Không cần gửi báo cáo playtest hay hoàn thành checklist trước khi tiếp tục; user sẽ báo bug nếu gặp.

`progress.json` vẫn giữ kết quả đã chạy, failure chưa rõ nguyên nhân và quyết định miễn acceptance. Các bản cũ của checklist có trong Git; không xóa lịch sử test hoặc coi failure đã được sửa.

## Bản đã giao gần nhất

- Windows: `C:\Users\permees\Downloads\DisasterParty-public-0d10b28`.
- Build: `0d10b289520f43889dd19cf5beba9c2abbaaea92`; endpoint: `https://server.permees.com`.
- Khi có bản mới, client/server cần matching. Bỏ checklist không cho phép tăng capacity, restart/deploy server hoặc đổi hạ tầng. Scope playtest vẫn1–4 người.
- Xác nhận Internet/audio của bản trước do user cung cấp vẫn được giữ; không suy thành xác nhận cho mọi bản sau.

## Nếu gặp bug

Gửi ngắn: `build — thao tác — kết quả mong đợi — kết quả thực tế — số người/mạng — máy/độ phân giải — log/screenshot nếu có`.

Không bắt buộc recording hay mẫu báo cáo dài. Agent sẽ tái hiện, xác định owner, sửa và kiểm chứng theo bug được báo; chỉ thêm một mục kiểm tra có mục tiêu nếu fix thực sự cần user/device/network xác nhận.
