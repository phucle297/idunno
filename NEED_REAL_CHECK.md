# Báo lỗi khi gặp thực tế

**Báo cáo mới của owner — hiệu năng multiplayer (2026-10-19, chưa phân loại):**
Solo khá mượt; mở2 app trên cùng máy, vào cùng room gây nóng máy và drop khung hình.
Chưa có build/OS/CPU/GPU/độ phân giải/FPS/thời lượng/map/hazard; không tự gán báo cáo
cho build public hay kết luận thermal throttle/network bug. [Phase19 checkpoint](docs/old-docs/phase-19-multiplayer-frame-budget/checklist.md).
Chưa tái hiện trên máy owner; orb không thay đo GPU/nhiệt độ thật. Nếu có thêm dữ
liệu, ghi build/cấu hình/độ phân giải, cả2 cửa sổ mở hay1 minimize, chơi bao lâu và
FPS solo/2 app; ảnh/log không bắt buộc. Đây không phải checklist chặn tiếp tục và
không đóng các giới hạn/waiver cũ.

**Checkpoint tối ưu agent (2026-10-19):** selective shadows giữ bóng props động,
cache roster không đổi, bỏ weather overlay khi hoàn toàn khô đã commit/push.
Dry draw calls8618–8627→4089–4098; đối chứng riêng overlay giảm median frame
interval khoảng36% trên llvmpipe, không suy thành FPS/nhiệt máy thật. Đã chạy
room4 client Rain/di chuyển liên tục hơn16 phút, đo node/RSS/UDP, hai renderer
Harbor Snow1080p và Town Rain720p; regression60 suite/7 matrix/managed20/46 Python.
Không xóa hình học/collision hoặc giảm tick server. Focus/minimize chung desktop,
GPU/Windows/nhiệt thật và diagnostic matrix mở rộng vẫn chưa hoàn tất.
[Số đo/giới hạn](docs/old-docs/phase-19-multiplayer-frame-budget/progress.json).
Source checkpoint khi đó chưa release/deploy; các tối ưu nay có trong Phase20
bên dưới, nhưng không tuyên bố đã sửa hết triệu chứng máy owner.

**Bản public hiện tại — Phase21 Hidden-Fuse Bomb (2026-10-22):**
[Source](https://github.com/phucle297/idunno/commit/60653104fad73fdfc738ab0a0109af0f4a11f4f0),
[deploy thành công](https://github.com/phucle297/idunno/actions/runs/39727391218),
[prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-22-6065310).
Tải `DisasterParty-Windows-Internet-6065310.zip`,giải nén hết,chạy EXE cạnh PCK;
tất cả người chơi cần cùng bản khi vào https://server.permees.com.
Trong room chọn Hot Potato (2+),Ready lại,F nhặt bom,chuột trái chuyền.
Fuse ngẫu nhiên chỉ server giữ,không countdown/reset/grace;nhận xong nổ ngay là
chủ ý. Nổ tạo lực đẩy,không trừ HP trực tiếp. Normal/Hard và16 toys cũ giữ nguyên.
Exact deployed-PCK104bom/20presentation/33menu,standalone Linux và public2client
trang phục/Ready/Start/di chuyển/nhặt/chuyền/nhận/nổ tự nhiên/impulse/100HP đều pass.
Windows có PCK trùng byte server;asset đã tải lại,hash/byte/tag khớp.
[Delivery evidence](docs/old-docs/phase-21-hidden-fuse-bomb/delivery-2026-10-22.json)
và [source regression](docs/old-docs/phase-21-hidden-fuse-bomb/progress.json).
Ảnh Choose Map của CI-PCK đã xem;hai client cùng orb/upstream,không thay thế
Windows/GPU/loa/nhiệt/FPS/hai mạng riêng hoặc cảm nhận chơi thật. Giữ waiver,
không thêm checklist bắt buộc. Public profile store vẫn tắt;không thay đổi infra.

**Bản public trước — Phase20 Toybox Chaos (2026-10-21):**
[Source](https://github.com/phucle297/idunno/commit/42796509f2d353541a2bd2e232e417b98163b6ad),
[deploy thành công](https://github.com/phucle297/idunno/actions/runs/39626771256),
[prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-21-4279650).
Tải `DisasterParty-Windows-Internet-4279650.zip`, giải nén hết,chạy EXE cạnh PCK;
tất cả người chơi cập nhật cùng bản khi vào https://server.permees.com.
16 đồ chơi sabotage,các combo nước/mưa rửa soap,quạt lệch đạn,cleanup khi
ngập/mất nền và giảm mật độ khi map sập;giữ giới hạn effect và hồi phục chống
chain-lock. F lấy/đổi đồ,chuột trái dùng. Các tối ưu Phase19 cũng được giao.
Regression63Godot/8matrix/managed20/46Python,both-map4/8/20 và5rematches pass.
Exact deployed-PCK345authority/96weather/11audio,sáu ảnh720p/1080p đã xem,
standalone Linux và public2client trang phục/Ready/Start/di chuyển/thoát pass.
Gói Windows chứa PCK trùng byte CI đã deploy;asset tải lại/hash/tag đều khớp.
[Toàn bộ evidence/giới hạn](docs/old-docs/phase-20-toybox-sabotage/progress.json#delivery_followup).
Chưa xác minh nhiệt/FPS trên máy owner,Windows/GPU/loa thật,human fun/hai mạng
riêng;waiver giữ nguyên,không thêm checklist bắt buộc. Có seam mảnh ở nền lát
góc dưới phải trong ảnh khô;chưa xác định nguyên nhân,không coi là đã sửa.
Magnet/crate relocation vẫn hoãn vì chưa chứng minh an toàn đường thoát;
public profile store vẫn tắt. Các bản dưới đây là lịch sử,không phải public mới.

**Source checkpoint Phase21 — trước lần release/deploy bên trên (2026-10-22):**
[Bom](https://github.com/phucle297/idunno/commit/cce0b84ec8193d183787a052c408ef3afd59d1e2)
và [sửa chuyển multiplayer → solo](https://github.com/phucle297/idunno/commit/469ea77d4579af5d1c2076010ab04fe3636dfb37)
đã commit/push, giữ nguyên public Phase20 phía trên. Hot Potato là chế độ2+ người;
F nhặt,chuột trái chuyền;thời gian ngẫu nhiên chỉ server giữ,không countdown,
không reset khi chuyền và chấp nhận nhận xong nổ ngay. Full65 suite/9 matrix/
managed20/46 Python và hook56 affected roots cho bản sửa solo đều pass;ảnh hai
map720p/1080p đã xem. [Evidence](docs/old-docs/phase-21-hidden-fuse-bomb/progress.json).
Không suy thành kiểm chứng Windows/GPU/loa/nhiệt/FPS hoặc cảm nhận chơi thật;
không thêm checklist bắt buộc và không áp kết quả này cho public cũ.

**Bản public trước — Phase18 Outfits và Original Music (2026-10-19):**
[Source](https://github.com/phucle297/idunno/commit/741ae3420da5b4c98c6d24b19344ffd5fbe6c341),
[deploy thành công](https://github.com/phucle297/idunno/actions/runs/39184818543),
[prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-19-741ae34).
Tải `DisasterParty-Windows-Internet-741ae34.zip`, giải nén hết rồi chạy EXE cạnh PCK;
mọi người cập nhật cùng bản khi vào https://server.permees.com.
Sửa click/Equip Outfit offline, thêm Chef/Firefighter/Sailor/Pilot miễn phí và hai
loop nhạc menu/gameplay, âm lượng Music riêng. 60 suite/7 matrix/managed20/42 Python,
settings restart và chuột X11 thật24 pass. Exact deployed-PCK Collection52/Music22,
ảnh Chef/Pilot720p, standalone Linux và public2 client Ready/Start/trang phục/
di chuyển đồng bộ pass. Windows chứa PCK đúng byte CI đã deploy; cả hai asset đã
tải lại đối chiếu byte/hash, tag trỏ đúng source. [Delivery evidence](docs/old-docs/phase-19-multiplayer-frame-budget/progress.json#delivery_followup)
và [source checkpoint](docs/old-docs/phase-18-outfit-selection-and-costumes/progress.json).
Archive Phase18 ghi source-only lúc đóng; delivery follow-up trong Phase19 supersede.
Windows/GPU/loa thật, cảm nhận điều khiển và hai mạng riêng chưa xác minh; public
profile storage vẫn tắt. Giữ waiver và mọi giới hạn cũ, không thêm checklist bắt buộc.
Nếu gặp lỗi, báo build/trang phục/màn hình, thao tác và số người/mạng; với nhạc ghi
lúc menu/vào trận/cảnh báo và giá trị Music Volume. Ảnh/log nếu thuận tiện.

Các bản dưới đây là lịch sử, không phải public hiện tại.

**Bản public trước — Phase17 Continuous Weather và Town Mechanisms (2026-10-18):**
[Source](https://github.com/phucle297/idunno/commit/4d23849908f6486aa6133a1d641a3d783d25f8b9),
[deploy thành công](https://github.com/phucle297/idunno/actions/runs/39139115103),
[prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-18-4d23849).
Tải `DisasterParty-Windows-Internet-4d23849.zip`, giải nén hết, chạy EXE cạnh PCK;
mọi người cập nhật cùng bản khi vào https://server.permees.com.
Mưa/tuyết phủ liên tục, mái che chặn precipitation, khô/tan dần; wet/snow/ice có
traction riêng. Nhấn E gần tay quay khi còn sống/đứng vững để xoay mái che/cầu.
59 suite/7 matrix/20 managed client/41 Python, 280 roof controls, ảnh exact-PCK,
standalone Linux và public hai client Ready/Start/di chuyển đồng bộ pass.
Assets tải lại so byte pass; Windows chứa PCK đúng bản CI đang deploy.
[Evidence](docs/old-docs/phase-17-continuous-weather/progress.json).
Windows gốc/GPU/60FPS/audio/cảm nhận điều khiển và hai mạng riêng chưa xác minh;
public profile storage vẫn tắt, packet-loss stress cũ vẫn deferred. Giữ waiver,
không thêm checklist bắt buộc. Nếu gặp lỗi, báo build/map/vị trí/thời tiết,
thao tác với mái/cầu và số người/mạng; ảnh/log nếu thuận tiện.

Các bản dưới đây là lịch sử, không phải public hiện tại.

**Bản public trước — Phase16 Animated Rooftop và Toy Town Fixes (2026-10-17):**
[source](https://github.com/phucle297/idunno/commit/a2c8ce87800de80784fa87837889005bd92d6288)
đã push, [deploy](https://github.com/phucle297/idunno/actions/runs/39059570910) và
[publish prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-17-a2c8ce8).
Tải `DisasterParty-Windows-Internet-a2c8ce8.zip`, giải nén hết rồi chạy EXE cạnh PCK.
Home rooftop3D có animation; flow Home → Choose Map → Start Solo được giữ nguyên.
Đã giảm fall damage theo độ cao, sửa HP lẻ hiển thị0, dời cây khỏi lối lên,
chỉnh Volcano, hình dạng vũng nước và bỏ vòng tròn Flood thường.
58 suite/6 matrix/managed20/41 Python, ảnh exact-PCK720p/1080p đã inspect,
standalone Linux và public hai client HTTPS/ENet/Ready/Start/di chuyển đồng bộ pass.
Windows dùng PCK giống byte server đang deploy; tag/assets tải lại so hash/byte pass.
[Evidence đầy đủ](docs/old-docs/phase-16-animated-rooftop-home/progress.json).
Mọi người cần cùng bản mới khi vào `https://server.permees.com`.
Public profile storage vẫn tắt; test lưu outfit/reward local không chứng minh
persistence trên public. Windows gốc/GPU/60FPS/audio/cảm nhận animation, thẩm mỹ,
cân bằng fall và hai mạng riêng vẫn chưa xác minh; waiver cũ giữ nguyên.
Không thêm checklist bắt buộc. Nếu gặp bug, báo build, map/trang phục, thao tác,
độ cao/vị trí nếu liên quan, số người/mạng và ảnh/log nếu thuận tiện.

Các bản dưới đây là lịch sử, không phải public hiện tại.

**Bản public trước — Phase15 Home và Choose Map (2026-10-16):**
[source](https://github.com/phucle297/idunno/commit/3e2d93898aff300f5f86dc41b737473329423876)
đã commit/push/deploy và [publish prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-16-3e2d938).
Tải `DisasterParty-Windows-Internet-3e2d938.zip`, giải nén hết rồi chạy EXE cạnh PCK.
Home độc lập → Play Solo → Choose Map → Start Solo; Back giữ lựa chọn.
Outfits có preview nhân vật thật; gồm sửa tay khi nhảy/mặt khi dừng của Phase14.
Multiplayer dùng `https://server.permees.com`; mọi người phải dùng cùng bản mới.
57 suite/6 matrix/managed20/41 Python, chuột X11 thật, ảnh720p/1080p,
exact-deployed-PCK render, standalone Linux và public2 client Ready/Start/movement
đã pass; tag/asset đã tải lại so byte/hash. [Evidence](docs/old-docs/phase-15-home-and-map-selection/progress.json).
Public profile storage vẫn tắt như trước; test profile/reward local không phải
xác nhận inventory earned được lưu trên public. Không suy thành Windows gốc,
GPU/60FPS/audio/cảm nhận animation hoặc hai mạng riêng đã pass. Giữ waiver cũ,
không thêm checklist bắt buộc. Nếu gặp lỗi, ghi build, màn hình/map, trang phục,
thao tác và lúc nhảy/rơi/dừng hay mất kết nối; ảnh/video nếu thuận tiện.

Các mục bên dưới là snapshot lịch sử, không phải trạng thái public hiện tại.

**Source Phase14 đã push, chưa deploy/release:** [source](https://github.com/phucle297/idunno/commit/5296ce2b81f711ef2f426768c6e97fc53255f687)
sửa tay khi nhảy, mặt khi dừng và
menu chuẩn bị chọn solo/phòng, map, chế độ trận, trang phục. Khi có build matching,
nếu còn lỗi hãy ghi lúc nhảy/rơi/dừng hay ngắt shove/get-up và bộ đồ đang dùng.
57 suite/6 matrix/managed20 và41 Python pass; [evidence](docs/old-docs/phase-14-character-stability-and-preparation/progress.json).
Automation/render Linux không thay cảm nhận animation hoặc Windows/GPU thật.
Không thêm checklist bắt buộc, không tự áp dụng báo lỗi này thành pass.

**Bản public mới nhất — Phase13 Expanded Toy Town (2026-10-16):**
[775f6c4](https://github.com/phucle297/idunno/commit/775f6c42a208afcef0ee424a308a5e1841099c50)
đã deploy và [publish prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-16-775f6c4).
Tải `DisasterParty-Windows-Internet-775f6c4.zip`, giải nén hết rồi chạy EXE cạnh PCK;
mọi người dùng cùng bản này với `https://server.permees.com`, client cũ không tương thích.
Gồm Town144m/19 building+nội thất/court/cầu mới và Speed/Jump của Phase12.
55 suite/6 matrix/managed20,41 Python, exact deployed-PCK layout6874, standalone
Linux/profile restart và public2 client HTTPS/ENet/Ready/Start/remote movement pass.
Hai archive đã tải lại đối chiếu byte/hash; phòng smoke đã được dọn.
Smoke là hai client Linux cùng orb/upstream, **không phải** xác nhận Windows gốc,
GPU/60FPS/audio/cảm nhận người chơi/hai mạng riêng. Không thêm checklist bắt buộc;
waiver và mọi báo lỗi cũ giữ nguyên. Nếu gặp lỗi, ghi build, map/vị trí, trạng thái
cầu/terrain, số người và thao tác tái hiện; ảnh/video nếu thuận tiện, không bắt buộc.
[Evidence Phase13](docs/old-docs/phase-13-map-physical-design-and-detail/progress.json).
Những trạng thái bên dưới là snapshot lịch sử.

**Phase12 hoàn tất gate kỹ thuật/local, source đã push (2026-10-15):** Speed (+20% chạy12s) và
Jump (+20% độ cao10s) đã implement, một buff/người, nhặt cùng loại làm mới thời gian,
khác loại thay thế. Test105/111 và cả hai map2/4/8/20 peer/five rematches đã pass;
ảnh720p/1080p được inspect.54 suite/6 matrix/managed20 và41 Python pass; matching
Windows/Linux125-entry PCK và standalone lifecycle đã kiểm tra; **chưa deploy/release**,
public vẫn Phase11 bên dưới. Không ghép client Phase12 với server public Phase11.
Native Windows/GPU/60FPS/audio/người thật/hai mạng riêng chưa xác minh; waiver cũ
giữ nguyên, không thêm checklist bắt buộc. [Evidence Phase12](docs/old-docs/phase-12-match-powerup-drops/progress.json).

**Bản public mới nhất — Phase11 (2026-10-15):**
[6e3adb1](https://github.com/phucle297/idunno/commit/6e3adb19c4b1c66de3b1f07d0f36bb348f0d5600)
đã commit/push/deploy và có
[prerelease](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-15-6e3adb1).
Tải `DisasterParty-Windows-Internet-6e3adb1.zip`, giải nén hết rồi chạy EXE;
client cũ không tương thích. Trung tâm/kho không còn miễn sập; đất và công trình
biến mất, nền xanh hiện bên dưới, rơi xuống chết ngay. Các lỗi Oracle về support,
rubble và reset/rematch client đã sửa.52 suite/41 Python, collapse8/8 trường hợp
hai map2/4/8/20 peer với5 rematch, exact-PCK4142, standalone Linux và public
HTTPS/ticket/2 ENet client/Ready/Start/ACTIVE/remote movement pass. Windows dùng
đúng PCK đã deploy; tag và ba asset publish đã tải lại đối chiếu byte/hash.
Public smoke là hai client Linux cùng orb/upstream; Windows gốc/GPU/60FPS/audio/
người thật/hai mạng riêng **chưa xác minh**. Không thêm checklist bắt buộc;
waiver và mọi xác nhận cũ giữ nguyên, không suy thành pass cho build mới.
[Evidence Phase11](docs/old-docs/phase-11-meteor-terrain-collapse/progress.json).
Các bản và trạng thái public trước bên dưới là lịch sử, đã được thay bởi bản này.

**Cập nhật public Phase10 (2026-10-15):** source
[945aa9f](https://github.com/phucle297/idunno/commit/945aa9f69631439c46b78983270b016f6668676c)
đã commit/push/deploy, gồm Volcano gồ ghề mới. Dùng gói được giao
`DisasterParty-Windows-Internet-945aa9f.zip`; client Phase9 không tương thích.
49 suite/5 matrix/managed20/settings restart và41 Python pass; exact CI-PCK
Volcano284/Integration47, standalone Linux và public HTTPS/ticket/2 ENet client/
Ready/Start/ACTIVE/remote movement pass. Hai client Linux cùng orb/upstream,
không thay xác nhận Windows gốc/GPU/audio/người thật/hai mạng riêng. Không thêm
checklist bắt buộc; waiver giữ nguyên. Các đoạn source chưa commit/public Phase9
bên dưới là snapshot lịch sử. Hash/gate giao hàng nằm trong root `progress.json`.

**Phase10 hoàn tất gate kỹ thuật/local (2026-10-15):**
Ong/UFO/núi lửa đã implement ở source và có gói matching Windows/Linux local tại
`.amp/in/artifacts/phase10-packages`; đây là snapshot chưa commit, không phải bản public.
Không ghép client này với server Phase9. Kiểm tra tự động và render phần mềm không
thay xác nhận Windows gốc/GPU/audio/người thật/hai mạng riêng. Waiver cũ giữ nguyên;
không thêm checklist người dùng bắt buộc.49 suite/5 matrix/managed20,41 Python test,
Town/Harbor2/4/8/20 peer với5 rematch,40 ảnh và exact-PCK/standalone Linux pass.
[Evidence](docs/old-docs/phase-10-swarms-ufo-volcano/progress.json) và
[checklist Phase10](docs/old-docs/phase-10-swarms-ufo-volcano/checklist.md) đã archive.
Source chưa commit/push; public Phase9 không đổi; Phase11/12 chưa bắt đầu.

**Phase9 hoàn tất gate kỹ thuật/local (2026-10-14):**
[Checklist/evidence](docs/old-docs/phase-9-weather-rockslides/checklist.md).
Rain/Snowfall/Rockslide chạy trên cả hai map;45 suite/5 matrix/managed20 và
Town/Harbor2/4/8/20 peer với5 rematch/reset pass. Gói Windows/Linux matching local
tại `.amp/in/artifacts/phase9-packages`, ảnh đã inspect tại `.amp/in/artifacts/phase9`.
User sau đó duyệt release/deploy; source c0a7800 đã push, EC2 và pre-release matching
đã kiểm tra. Gói uncommitted local ở trên là evidence lịch sử, không ghép với server public.
Native Windows/GPU/audio/người thật/hai mạng riêng chưa xác minh; waiver cũ giữ
nguyên, không thêm checklist người dùng bắt buộc. Đây là trạng thái lịch sử trước Phase10.

**Follow-up collision:** [evidence](docs/old-docs/phase-8-collision-followup/checklist.md)
cho lan can, bụi/chậu cây, đèn, vent, cọc/crate Harbor đã có trong bản public e68a912.
Lan can trình bày cầu thang giữ decorative trên ramp solid để không chặn đường
tiếp cận hoặc crate crossing. CI pass42 suite/5 matrix/managed20; lỗi fixture prop
reset được sửa bằng freeze/ack trong test, không nới tolerance hoặc sửa physics thật. Native/GPU/user acceptance
và waiver cũ không đổi. Drop tăng tốc/nhảy khi đó chỉ là plan Phase12; trạng thái
hiện tại ở đầu trang, không thêm checklist người dùng bắt buộc.

**Phase8 hoàn tất gate kỹ thuật (2026-10-14):** [checklist và evidence](docs/old-docs/phase-8-character-disaster-counterplay/checklist.md).
Source `14be2c323e2267c18a06ccf704090c6268ad184e` đã push; gói matching Windows/Linux
local tại `.amp/in/artifacts/phase8-packages` đã kiểm hash/unpack/lifecycle/profile
restart. Gói local cũ là lịch sử; **dùng client public Phase9 c0a7800 matching server hiện tại**.
Crouch/cầm đồ đã bỏ, animation Shift giữ phase, quake có vùng nứt/đường thoát,
Flood dập Fire ngập và meteor theo diện tích. Native Windows/GPU60FPS/audio/người thật/
hai mạng riêng chưa xác minh, waiver cũ không đổi; không thêm checklist bắt buộc.
Phase9 đã hoàn tất source/local gates và public delivery như ghi phía trên.
Các câu Phase8 chưa implement/tạm dừng bên dưới là snapshot
lịch sử, không phải trạng thái source hiện tại.

**Planning tiếp theo:**
Phase9 thời tiết/đá lở, Phase10 ong/UFO/núi lửa. Safe zone Phase8 cũ chuyển sang
scope vòng co nhưng owner đã hủy; thay bằng
[Phase11 — Meteor Terrain Collapse](docs/old-docs/phase-11-meteor-terrain-collapse/checklist.md)
(snapshot scope cũ lưu ở `docs/old-docs/phase-11-superseded-zone/`). Disaster Phase9
đã chạy trong source/package/public c0a7800; Phase10 đã commit/deploy `945aa9f`.
Phase11 đã hoàn tất, commit/push/deploy và publish matching prerelease như ghi đầu
trang; toàn bộ evidence/checklist/decisions đã archive. Phase12 sau đó được owner
cho tiếp tục implement, trạng thái hiện tại ở đầu trang.
Tương tác búa/mảnh gỗ chỉ nằm trong backlog. Phase2 đã chuyển
vào old-docs, chỉ mở lại khi user yêu cầu, chưa đánh dấu hoàn tất. Báo cáo hazard/
animation của user được giữ làm đầu vào tái hiện, không tự đánh dấu đã fix. Không thêm checklist
người dùng bắt buộc; đánh giá cảm giác/challenge/GPU dùng đúng build sau khi có.

**Bản public hiện tại (2026-10-14):** [Weather and Rockslides Playtest](https://github.com/phucle297/idunno/releases/tag/playtest-2026-10-14-c0a7800),
tải `DisasterParty-Windows-Internet-c0a7800.zip`, giải nén toàn bộ và chạy `DisasterParty.exe`.
Client/server/tag cùng revision `c0a780067c10372ca6676725f03916503994aa5e`;
endpoint `https://server.permees.com`. User duyệt deploy/release riêng; staged pre-commit
pass45 suite,5 matrix,managed20,settings restart và41 Python test; workflow build/deploy
pass backend readiness, không chạy test trong deployment. PCK Windows
giống hệt artifact CI đã deploy; ba asset release tải lại/hash/tag đã kiểm tra.
Public smoke hai client Linux Godot dùng final PCK pass TLS/tickets/ENet/
Ready/Start/ACTIVE,remote movement và404 unknown-room/409 old-build; cùng một orb/upstream,
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
