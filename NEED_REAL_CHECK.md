# Báo lỗi khi gặp thực tế

**Follow-up collision:** [evidence](docs/old-docs/phase-8-collision-followup/checklist.md)
cho lan can/cầu thang, bụi/chậu cây, đèn, vent, cọc/crate Harbor. Source đã sửa;
gói Phase8 dưới đây chưa có follow-up, chưa export/deploy/release bản mới. Test capsule,
đường đi/rematch và2/4 peer hai map đã chạy; một scene fixture phụ lỗi quan sát prop
reset được giữ trong log, không sửa tolerance để giấu lỗi. Native/GPU/user acceptance
và waiver cũ không đổi. [Drop tăng tốc/nhảy](docs/checklists/phase-12-match-powerup-drops.md)
chỉ là plan Phase12, chưa implement; không thêm checklist người dùng bắt buộc.

**Phase8 hoàn tất gate kỹ thuật (2026-10-14):** [checklist và evidence](docs/old-docs/phase-8-character-disaster-counterplay/checklist.md).
Source `14be2c323e2267c18a06ccf704090c6268ad184e` đã push; gói matching Windows/Linux
local tại `.amp/in/artifacts/phase8-packages` đã kiểm hash/unpack/lifecycle/profile
restart. Không deploy/release; **không dùng client Phase8 với server public2619665**.
Crouch/cầm đồ đã bỏ, animation Shift giữ phase, quake có vùng nứt/đường thoát,
Flood dập Fire ngập và meteor theo diện tích. Native Windows/GPU60FPS/audio/người thật/
hai mạng riêng chưa xác minh, waiver cũ không đổi; không thêm checklist bắt buộc.
Phase9 chưa bắt đầu. Các câu Phase8 chưa implement/tạm dừng bên dưới là snapshot
lịch sử, không phải trạng thái source hiện tại.

**Planning tiếp theo:**
Phase9 thời tiết/đá lở, Phase10 ong/UFO/núi lửa. Safe zone Phase8 cũ chuyển sang
[Phase11](docs/checklists/phase-11-shrinking-survival-zone.md). Chưa implement hoặc
deploy Phase9–11. Tương tác búa/mảnh gỗ chỉ nằm trong backlog. Phase2 đã chuyển
vào old-docs, chỉ mở lại khi user yêu cầu, chưa đánh dấu hoàn tất. Báo cáo hazard/
animation của user được giữ làm đầu vào tái hiện, không tự đánh dấu đã fix. Không thêm checklist
người dùng bắt buộc; đánh giá cảm giác/challenge/GPU dùng đúng build sau khi có.

**Bản public hiện tại (2026-10-14):** [Integrated Town Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-2619665),
tải `DisasterParty-Windows-Internet-2619665.zip`, giải nén toàn bộ và chạy `DisasterParty.exe`.
Client/server/tag cùng revision `2619665ce31e02dd7233e9099c0d5a6e8c9a2e2d`;
endpoint `https://server.permees.com`. User duyệt deploy/release riêng; CI/deploy pass
42 suite, 5 matrix, managed20, settings restart và34 room-service test. PCK Windows
giống hệt artifact CI đã deploy; ba asset release tải lại/hash/tag đã kiểm tra.
Public smoke hai client Linux editor dùng final PCK pass TLS/tickets/ENet/roster/
Ready/Start/remote movement/owner transfer, RTT103ms; cùng một orb/upstream,
không thay xác nhận Windows gốc/GPU/audio/hai mạng người thật. Giữ nguyên cấu hình
EC2 và giới hạn phòng/người; không bật profile store mới. Chunk streaming và safe
zone chưa có. Các mục "chưa deploy" bên dưới là snapshot lịch sử, không phải trạng
thái bản public hiện tại. Client cũ không tương thích; waiver vẫn giữ nguyên.

**Integrated town (2026-10-14):** sửa tiếp theo phản hồi7S: Town112×112m,
tường/cornice liền góc, canopy cong/scallop, nền lát đồng bộ, khu dân cư/thương mại,
civic terrace và garden có cao độ/collision thật, cầu thang có bậc/lan can/gối đỡ.
Ảnh tham chiếu gốc vẫn trong source. Render và test tự động không thay xác nhận
thẩm mỹ; chưa claim giống hoàn toàn concept hoặc60FPS/GPU thật. Bản source này
không phải release đang chạy public; chưa deploy/release, Phase8 vẫn tạm dừng.
Không thêm checklist người dùng bắt buộc; waiver và evidence cũ giữ nguyên.

**Rounded rebuild (2026-10-14):** user đã bác bỏ hình ảnh7R vì còn vuông. Đợt7S thay mesh bo nhỏ bằng bề mặt cong nhiều segment và sửa mái hiên/cây/xe/nội thất theo [ảnh user cung cấp](assets/references/phase7/rounded-town-camera-reference.png). Render cùng camera và regression đạt; chưa có xác nhận thẩm mỹ từ user, chưa đo GPU thật. Layout, mật độ chi tiết và ánh sáng vẫn đơn giản hơn concept. Bản sửa chỉ giao source, không deploy/release và không bắt đầu Phase8; waiver không đổi.

**Đính chính Phase7 (2026-10-14):** kết luận hoàn tất hình ảnh dưới đây là lịch sử và đã bị supersede. Audit cho thấy Phase7 cũ chưa đổi source UI; test chức năng không chứng minh khớp concept. [Đợt sửa đã push source](docs/old-docs/phase-7-visual-correction/checklist.md) bổ sung UI/nhân vật/môi trường và [ảnh thiết kế gốc](assets/references/phase7/README.md). Ảnh render mới được kiểm tra trên Linux llvmpipe720p/1080p, không thay thế đánh giá thẩm mỹ của bạn hoặc native Windows/GPU/60FPS. Chỉ push source theo yêu cầu; chưa deploy/release bản sửa, Phase8 chưa bắt đầu. Waiver cũ vẫn giữ, không thêm checklist bắt buộc.

Theo yêu cầu user ngày2026-10-09, bỏ các checklist kiểm tra thủ công hiện tại và yêu cầu baseline/follow-up2.4–2.6 để tiếp tục phát triển. Đây là **waiver theo quyết định user**, không phải bằng chứng đã thực hiện hoặc pass những test chưa chạy. Không cần gửi báo cáo playtest hay hoàn thành checklist trước khi tiếp tục; user sẽ báo bug nếu gặp.

Phase6 đã hoàn thành và [archive](docs/old-docs/phase-6-cosmetic-loot-box-drops-and-customization/progress.json): profile/store, reward/open/equip, tám outfit và UI, test local4/8/20 cùng gói matching; chưa deploy/publish. Phase7 cũng đã hoàn thành và [archive](docs/old-docs/phase-7-soft-creature-world-and-interface/progress.json): Soft Creature bean + tám outfit + ragdoll, camera cao, nội thất town/harbor, disaster matte, giao diện đầy đủ, regression 42 suite + 5 matrix + managed 20-client; tất cả gate agent pass nhưng **chưa** xác minh GPU thật/native Windows/60FPS/audio/Internet; llvmpipe p95 chưa đạt 16.67ms (Xem mục 60FPS GPU bên dưới). Không thêm checklist user bắt buộc; việc nhìn "đẹp/chân thật hơn" vẫn thuộc người thật đánh giá khi chạy build thật, agent không suy thành pass. [Archive Phase5](docs/old-docs/phase-5-session-distribution-and-release-readiness/progress.json), [follow-up](docs/old-docs/phase-5-validation-followup/progress.json), [Phase4](docs/old-docs/phase-4-disaster-remix-and-toy-town-interaction/progress.json), [Phase3](docs/old-docs/phase-3-player-caused-chaos/progress.json) và [Phase2](docs/old-docs/phase-2-human-playtest-and-core-feel/progress.json) giữ kết quả lịch sử; Phase2 vẫn hoãn. Kết luận "mọi gate agent đã pass" không áp dụng cho GPU thật, native Windows hoặc human/network/audio acceptance chưa chạy; llvmpipe chưa đạt60FPS. [Audit reconciliation](docs/old-docs/phase-5-validation-followup/decisions.md) vẫn giữ nguyên; không sửa/xóa evidence cũ.

## Bản đã giao gần nhất

- Gói Phase6 local, **chưa deploy/publish**: `.amp/in/artifacts/phase6-packages/` — `DisasterParty-Windows-e978f6a.zip`, `DisasterParty-Linux-server-e978f6a.tar.gz`, `PLAYTEST-NOTES.md`. Source client/server `e978f6a13089250eaef998d8e907b10b62359fde`, PCK giống hệt, hash/unpack và standalone Linux profile restart/open replay/earned equip pass. Completion trong fixture là synthetic; không suy thành phiên người thật. **Không dùng client này với public server Phase5 cũ**. Native Windows/GPU/audio/Internet chưa xác minh; không chặn continuation theo waiver.
- Release lịch sử: [Phase 5 Hardening Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-12-bd3b606), gói `DisasterParty-Windows-Internet-bd3b606.zip`, revision `bd3b606971ce9cf5470e03c5945d229052eb5ddf`. Đã được thay bởi Integrated Town ở đầu trang; không dùng client cũ với server mới.
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
- **Matching build/network:** bản public hiện tại là Integrated Town revision `2619665ce31e02dd7233e9099c0d5a6e8c9a2e2d`, đã deploy và có exact-PCK public smoke; bản `0d10b28` giữ xác nhận lịch sử. Dùng Windows ZIP mới ở đầu trang và kiểm tra revision trong BUILD.txt; ghi số người, máy/mạng, movement/owner departure/crash retry/audio. Một phòng 20 client loopback không chứng minh nhiều phòng 20 người trên EC2; public smoke một orb không thay thế phiên người thật ở hai mạng riêng. Không tự deploy/restart thêm để thực hiện check.

## Kiểm tra Phase4 cần người chơi thật (không chặn bug report)

Phase4 đã hoàn thành và archive (2026-10-11); các mục dưới đây vẫn MỞ cho đến khi có người chơi thật xác nhận — automation không thay thế được. Milestone 4.4 yêu cầu so sánh Normal/Hard với người thật. Agent đã đo bằng mô phỏng cùng seed và cùng tier (Normal chết sau 24.0s, Hard sau 21.0s ở cùng hazard lethality — Hard mạnh hơn chỉ nhờ nhịp độ, không nhân damage; cùng run, độ phân giải 0.5s), nhưng không thay thế cảm giác thật và không claim mục nào pass. Chơi 1–4 người, ghi theo format báo bug ngắn ở trên:

- **So sánh thời điểm chết Normal/Hard:** chọn preset trong lobby (PRESET), chơi cùng map vài hiệp mỗi chế độ, ghi thời gian sống sót. "Harder" không đồng nghĩa "tốt hơn" — báo nếu Hard thấy unfair, stun-lock hoặc ngược lại thấy chả khác gì.
- **Nhận diện nguyên nhân chết không cần hướng dẫn:** sau mỗi lần chết hỏi "vì sao?" — mong người chơi đọc được cause (Flood/Tornado/Meteor/Impact Debris/Burning Rubble/Earthquake/Lightning/Fire) từ cảnh báo và HUD mà không ai giải thích. Báo nếu cause khó hiểu.
- **Thử thoát hiểm:** trong lúc cảnh báo hỏi người chơi có thấy đường thoát/cao điểm không, có thử đi tới đó không; báo nếu cảnh báo không đủ rõ để quyết định (đặc biệt combo Fire+Earthquake với rubble cháy).
- **Tự nguyện chơi lại:** sau hiệp đầu hỏi có muốn rematch/chơi tiếp không và vì sao; record phản hồi ngược.
- **Thời lượng thực tế:** ghi thời lượng mỗi hiệp (target 8–12 phút; `match_duration` hiện 600s và configurable) kèm số người/mạng/máy.
