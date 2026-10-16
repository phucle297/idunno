# Phase 13 — Toy Town lớn hơn, kết nối chặt và nhiều chi tiết

**Trạng thái: plan đã commit/push; implementation đang qua gate cuối.**
Ngày: 2026-10-16. Source được kiểm tra:
[`b2f0d12`](https://github.com/phucle297/idunno/commit/b2f0d12f25ef69cc3cfede8c4be46d4500be3e62).
Không thay `DESIGN.md`, không mở lại điều tra mạng đang được chủ dự án hoãn.
Chủ dự án sau đó yêu cầu “commit plan, then do till done”; plan đã push ở
[`85d5a8d`](https://github.com/phucle297/idunno/commit/85d5a8d).
Các đoạn “chưa triển khai” bên dưới là snapshot audit/proposal ban đầu, được thay
bởi nhật ký thực thi dưới đây. `progress.json` giữ kết quả/gate hiện hành.

### Nhật ký thực thi sau phê duyệt

- 144×144m,19 nhà kín +garage, frontage13m. Bốn court bổ sung có stair cạnh nhà
  và roof landing riêng; không còn dùng stair che trục cửa. Vòng ngoài4m và bốn
  stair ngang nối terrace; garden loop, allotment và picnic tạo điểm đến phía Nam.
- Garage shelf/toolbox dời khỏi lane rồi mới solid. Counter/desk/bed/sofa/shelves,
  pool edge, canopy proxies và rail có vật lý tương ứng. ParkRamp bỏ hình barrier
  xuyên người, thay bằng edge trim thấp để giữ shared crossing/crate route.
- Hai bridge dời lên khoảng hở thật giữa roof và annex; rail mất cùng deck khi
  broken/collapse. Roofwalk3.8m, gate rail district≥3.08m, curb0.12m có miệng flush.
- Cuts Town x[-72,-30,30,72], z[-72,-37,32,72]; mesh và sloped box cắt ở mặt phẳng
  đứng, không chỉ chia endpoint. Harbor giữ nguyên nội dung/extent/cuts.
- Layout6799 assertions qua: controller qua hai cửa của19 nhà, garage, hai bridge
  và single-region ownership. Collapse18108 assertions/278 legal masks qua, không
  còn lọc Town về Shop/Hall. Crowd fixture20/20 qua cầu trong2.13s; grid2m ghi
  4098/5041 outdoor sample usable (81.3%, ước lượng có điều kiện, không đo exact area).
- 41 Python tests qua. Full normal-clock regression, ảnh cuối và profile trước–sau
  đang chạy; chưa đánh dấu toàn phase complete hoặc suy ra native60FPS/người thật.

## 0. Scope mới của chủ dự án — thay thế phạm vi đề xuất ban đầu

**Chỉ tập trung Toy Town. Toy Harbor tạm hoãn**, giữ audit cũ làm bằng chứng chứ
không yêu cầu sửa Harbor trong phase này. Chủ dự án yêu cầu Town lớn hơn, chi tiết
hơn, công trình gần nhau hơn một chút, cầu và lề đường hợp lý hơn. Đã dùng Oracle
review source và plan; kết quả được đối chiếu với các builder hiện hành. Đây vẫn
là bước thay đổi thiết kế/kế hoạch, chưa phải map đã sửa hay build mới.

### 0.1 Phương án bố cục đề xuất sau Oracle review

**Lớn ở quy mô thị trấn, gọn ở quy mô cụm phố.** Không scale toàn bộ world hoặc
kéo giãn khoảng cách. Candidate greybox: **144 ×144 m** thay112 ×112 m, thêm8,192 m²
(+65.3% diện tích); chưa phải kích thước đã được gameplay/performance chấp nhận.
Nếu phần ngoài bị rời rạc/đi quá lâu, kiểm lại candidate128 m, không lấp bằng đồ lặp.

| Thành phần | Thiết kế đề xuất và lý do |
| --- | --- |
| Core | Giữ plaza18×18 và quan hệ dễ nhận ra giữa Shop/School/Garage/Park; sửa circulation, không kéo chúng ra xa để lấp map. |
| Hai dãy phố Đông/Tây | Với nhà8 m, thử center pitch13 m thay15 m: khoảng tường ngoài còn xấp xỉ4.7 m sau thickness, trước props. Cụm có thể dịch nhẹ từ x±42 vào±40 nếu đủ sidewalk. Không mặc định12 m vì canopy/rail/cửa có thể ăn hết clearance. |
| Hướng công trình | Frontage hướng ra street/promenade chung, cửa sau vào service court; không chỉ đổi khoảng cách mà giữ cửa chính nhìn vào lưng nhà bên cạnh. |
| Civic phía Bắc | TownHall/Residence/Studio là một cụm; forecourt rõ, stair recessed hoặc song song mép terrace. Không để cầu thang đè ngang road rồi giả định có underpass. |
| Garden phía Nam | Cafe, hồ, promenade và park nối thành loop; bench/planting ở pocket bên đường, không chắn trục cửa. |
| Bốn block bổ sung | Candidate24×24 tới28×24 m, bố trí theo bốn góc; mỗi block thêm một công trình nhỏ, court có công năng và hai kết nối vào mạng phố/terrace. Anchor cuối cùng phải chốt cùng collapse cuts, chưa đóng đinh tọa độ. |
| Công năng mới | Postal/service office, community activity room, garden pavilion, market storehouse. Tổng candidate19 enclosed building (15 cũ +4 mới), garage riêng; không thêm mechanic bưu điện/crafting/xe. |
| Vòng ngoài | Pedestrian/service circuit thông thoáng4 m, nối vào trong tại mỗi block; không thêm một grass moat hoặc road ring quá rộng. |

Các building trong block mới gần nhau theo frontage/courtyard; khoảng trống lớn là
quảng trường, sân và đường nhìn có chủ đích, không là đất thừa. Chi tiết theo ba lớp:
khối công năng → cấu tạo (chân, khung, viền, support) → accent/signage/goods gom nhóm.
Giữ palette, matte plastic, silhouette và shared material; không tăng rigidbody để trang trí.

### 0.2 Cầu, sidewalk, curb và landing phải thiết kế lại cùng nhau

| Hiện trạng xác minh từ source | Quyết định đề xuất |
| --- | --- |
| BridgeWest/East ở(±8,.25,9), slab3×.25×1.5; có nền ground/plaza liên tục bên dưới. Phá slab không làm mất crossing thật. | Đổi chỗ cũ thành pedestrian crossing flush. Chuyển hai breakable traversal roles thành **hai footbridge trên cao có khoảng hở thật tại cao độ deck**, giữa terrace/roof và annex có lối lên riêng. Không thêm kênh nước giả hoặc death pit mới. |
| Road Bắc z[-32,-28]; CivicStairs chạy z[-28,-35.05], chiếm road. Cao độ ở mép road chỉ khoảng1.16 m, underside còn thấp hơn. | Stair/forecourt recessed hoặc xoay dọc frontage, road phải đi liên tục. Không gọi đây là underpass dùng được; cần test controller/camera sau greybox. |
| Roofwalk3 m có post center±1.45, post dày.22: lọt lòng chỉ2.68 m. | Đo **clear width**, không đo slab: ≥3 m giữa rail; candidate overall deck3.6–3.8 m và rail đặt ra ngoài. Reauthor connector sau khi compact nhà, không đổi pitch mà giữ slab7 m cũ. |
| Curb là các segment visual-only, độc lập theo road cross cũ, không có model junction/arrival. | Dùng một bản vẽ circulation chung: road edge → sidewalk → crossing → cửa → stair. T/X corner liên tục; curb ngắt/flush đúng miệng đường, không chạy ngang landing/cửa/dốc. Không cần xây runtime graph framework mới. |

**Chuẩn greybox đề xuất:** road5 m; sidewalk≥3 m clear, node đông người4 m;
curb0.10–0.15 m với visual/collision thống nhất; crossing/door/garage transitions flush.
Bridge span4–6 m theo khoảng hở thực, ≥3 m clear giữa solid rail, landing4×4 m
hai đầu; rail và support phải mất cùng breakable deck, không để invisible foothold.
Bridge là shortcut, không là lối thoát duy nhất của annex hoặc roof chain.
Stair main≥3 m clear, civic/district ưu tiên4 m; landing sâu≥3 m, turn/merge4×4 m.
Garage arrival giữ4 m width và candidate4 m depth; headroom candidate≥2.4 m,
kiểm cả capsule lẫn camera. Rail nhìn như barrier phải chặn, nếu không thì đổi thành
edge trim thấp; không giữ pass-through handrail để chữa placement sai.

### 0.3 Collapse, hazard và refuge là ràng buộc của layout, không làm sau cùng

- **Source-level seam concern cần tái hiện:** Apartments/Market centerz23 có roof
  strips kéo từz18.7 tới27.3, cắt seamz20. Collapse cache tắt cả shape khi bất kỳ
  region giao nó bị xóa; có thể mất support phía ngoài vùng cảnh báo. Đây là suy luận
  source, **chưa runtime reproduce**, không gộp thành kết quả audit đã pass.
- Test legal-mask hiện lọc route Town còn Shop/Hall; không chứng minh mọi district
  roofwalk/stair an toàn. Hai exit point trên cùng mái không thay hai đường thoát hoàn chỉnh.
- Chốt building/landing/bridge và nine-region cuts **cùng lúc**. Giữ9 region,4 lần
  removal và schedule; không chỉ thay±56 thành±72 rồi giữ mọi seam cũ. Partition cả
  broad collision lẫn batched visual đúng ownership, tránh đồ mất ngoài warning.
- Cập nhật Town-only extent/base/boundary/kill queries, flood/meteor/lightning bounds,
  tornado paths/cover, fire positions/neighbors, weather candidates, rockslide lane
  hiệnx50, pickup/spawn pads, refuge/route anchors và meteor reserved routes. Không
  sửa fallback32 m chung làm Harbor to theo; không tự tăng damage/count theo diện tích.
- Mỗi neighborhood có destination tránh Flood và ít nhất hai kết nối hoàn chỉnh;
  covered room và exposed roof có tradeoff, không tạo góc mới miễn mọi disaster.
- Candidate gate: từ điểm đại diện tới refuge hữu ích trong8–12 giây đi thường,
  ra khỏi threatened district trong15 giây với đường không bị chen, để còn margin
  trong warning30 giây. Phải đo controller, không suy ra từ đường thẳng/toạ độ.
- Giữ≥40% usable outdoor không bị chướng ngại: nominal144² tương ứng khoảng8,294 m²;
  không double-count mái/nền hoặc dùng rìa không tới được để đủ số. Kiểm sightline
  từng phố, không bù một khu nghẹt đồ bằng một góc trống khổng lồ.

### 0.4 Thứ tự milestone mới — thay thứ tự triển khai cũ

Giữ ID13.1–13.5; phần checklist phía dưới được đọc theo phạm vi mới này.

1. **13.1 — Town topology/expansion greybox và physical truth:** bản vẽ footprint,
   block/road/sidewalk, bridge endpoints, landing và collapse cuts trước. Sau đó sửa
   garage/furniture/canopy/pool/roof/rail; controller đi được với đồ thực sự solid.
2. **13.2 — Functional interiors:** đủ15 building Town hiện có và4 candidate bổ sung;
   một mẫu frontage/interior trước, mỗi địa điểm có bản sắc. Không áp dụng Harbor.
3. **13.3 — Outdoor detail/cohesion:** core → dãy phố → civic/garden → bốn block/vòng
   ngoài; terrain joints, curb/crosswalk/landing và detail cùng circulation đã kiểm.
4. **13.4 — Whole-Town route/collapse/crowd acceptance:** đổi milestone Harbor trước
   đây thành kiểm mọi district route/bridge, support ngoài warning, escape sau các
   lần removal,20-player spawn/merge fixtures, pickup clear và5 rematch.
5. **13.5 — Regression/performance/delivery boundary:** profile trước–sau cùng điều
   kiện, map/hazard/network regression; Harbor chỉ regression cho helper dùng chung,
   **không làm nội dung Harbor**. Không tự commit/push/package/deploy từ plan.

- [ ] Greybox candidate144 m vượt baseline112 m, local13 m frontage pitch rõ hơn và
  không tạo ngoại vi bị cô lập; nếu không đạt, điều chỉnh layout/kích thước trước detail.
- [ ] Cả hai footbridge có topology thật và alternative route; pedestrian crossing không
  còn giả làm breakable bridge; Civic road không còn cầu thang/rail cắt ngang.
- [ ] Sweep/walk mọi district route trong relevant legal masks, bao gồm seam sample
  ở hai phía vùng cảnh báo; giữ support không thuộc vùng bị xóa.
- [ ] Door/turn/landing/camera và20-player merge được chạy thực tế; so sánh route time,
  footprint, open coverage, frame/physics/render baseline; không suy thành native60FPS.

## 1. Mục tiêu và ranh giới

Map phải vừa **nhìn có công năng**, vừa **hành xử đúng như hình nhìn thấy**:
đồ lớn không xuyên người, không có tấm vô hình, đường lên/ra khỏi chỗ trú không
bị đồ trang trí chặn. Tăng diện tích và độ chi tiết **Toy Town** bằng nội thất,
kiến trúc và bố cục có chủ đích, không bằng cách rải thêm block giống nhau.

- Giữ ngôn ngữ rounded toy-playset, palette/vật liệu chung và server authority.
- Giữ ít nhất 40% diện tích không bị chướng ngại theo `DESIGN.md`; chưa đo tỷ lệ hiện tại.
- Đường chính ≥3 m, cửa ≥1.8 × 2.2 m, tối thiểu hai lối ra/thoát mỗi refuge chính.
- Giữ đường sống sót dùng được với movement cơ bản, không cần Speed/Jump, nhảy khó
  hoặc đi xuyên mesh. Đồ tĩnh không tự trở thành grabbable/rigidbody.
- Mở rộng biên Town theo candidate ở§0; không thêm map mới, chunk streaming,
  điều khiển xe/cần cẩu, hazard mới hoặc sửa damage/cover chỉ để làm cảnh đẹp hơn.
- Chưa yêu cầu người dùng chạy lại checklist bắt buộc; waiver trong
  [NEED_REAL_CHECK.md](../../NEED_REAL_CHECK.md) giữ nguyên. Không suy ra aesthetic approval.

## 2. Audit thực tế: đã kiểm tra gì, chưa chứng minh gì

### Phạm vi và cách kiểm

- Đọc toàn bộ các builder Town/Harbor và helper collision trong `game/main.gd`.
- Instantiate scene thật với Godot 4.7.2; tắt thời gian/hazard tự chạy để audit map intact.
- Inventory **mọi visible MeshInstance3D trong Sandbox**: Town 3,006 mesh,
  1,211 physics body, 1,253 enabled shape; Harbor 354/111/142 tương ứng.
- 10,080 center-axis ray samples trên tổng 3,360 mesh để tìm ứng viên lệch hình/vật lý.
  **Không coi mọi sample không hit là lỗi:** lá cây, vạch sơn, trim, mesh rỗng/hở
  và trang trí dựa trên collider công trình đều cần phân loại theo công năng.
- 20 focused ray probes: 18 đường xuyên không hit, hai positive controls hit
  (bollard thật và tấm awning cũ). Đây là xác nhận hiện trạng, không phải test map đã đúng.
- Kiểm tra hai cửa và tâm mái của **16 building**: 32 tia qua cửa không gặp vật cản,
  16 tia từ trên xuống đều gặp roof/panel. Chỉ chứng minh các điểm mẫu, không chứng minh
  toàn bộ cửa/cạnh mái hay độ rộng capsule.
- Cho controller nhân vật thật đi từ đầu dốc garage vào deck, không chỉ kiểm tra node.
- 39 ảnh render thật: toàn cảnh hai map, các vùng ngoài trời, đủ 15 nội thất Town
  và Warehouse Harbor, lớp học, gầm garage, mái nhà và các chi tiết quan trọng.
  Đã mở xem trực tiếp 6 contact sheet; đây là camera audit độc lập, không phải
  bằng chứng SpringArm/camera gameplay đã đạt ở mọi góc.

**Bằng chứng phiên audit:** `.scratch/map-design-audit/audit.gd`, `audit.log`,
`inventory.json`; bản inventory tải xem và ảnh ở `.amp/in/artifacts/map-design-audit/`.
Các file này là artifact của phiên, không phải asset/gameplay source mới.

### Findings ưu tiên

| ID | Ưu tiên / độ chắc | Vị trí và hiện trạng | Hướng xử lý / điều kiện đạt |
| --- | --- | --- | --- |
| D01 | P0 / runtime + controller + ảnh | `ParkingGarage/ToolShelving`: center world (-15, 3.28, 10), kích thước 5 × 1.4 × 0.6 m; phủ x[-17.5,-12.5], z[9.7,10.3], ngay sau đầu dốc z9. Nhân vật đi từ (-15,2.595,9.2) tới (-15,2.576,12.061), vào volume kệ rồi ra, vẫn on-floor. | Dời/đổi hướng kệ và hai toolbox khỏi hành lang arrival **trước** khi thêm collider. Giữ trọn bề rộng dốc 4 m và khoảng đứng/đổi hướng trên deck; kệ mới phải chặn người, đường vào phải đi được không xuyên đồ. Không vá bằng bật `solid` tại vị trí cũ. |
| D02 | P1 / runtime mẫu + source toàn nhóm | Shop counter/stock shelf/crates; School 4 bàn + 2 coat rack; House kitchen/table/bed/sofa; Garage tools; Warehouse 3 rack, workbench, stack; cả 8 district counter/shelf/goods đều đang visual-only. | Collider đơn giản cho vật thể hữu hình, hợp nhất theo assembly khi phù hợp; đồ trên kệ không cần từng body. Quét capsule ngoài đường chính, giữ hai cửa và lối giữa; không còn ghost furniture trong vùng người chơi chạm được. |
| D03 | P1 / runtime + source | Shop và GardenCafe đổi sang canopy cong rộng 11.4/9.4 m nhưng giữ `EntranceAwning` collider cũ rộng 3.4 m. Tia ở Shop (-16,3.8,-6.2) xuống hit tấm cũ tại y3.44; phần mái ngoài x=-20 không hit. | Thay collider cũ bằng proxy mỏng khớp mái cong nếu có thể tiếp xúc; không để mặt phẳng vô hình làm chỗ đứng/che mưa ngoài hình. Test từ trên, dưới, rìa, jump buff và ray cover. Không thêm hộp đặc bao toàn khoảng không dưới mái. |
| D04 | P1 / runtime + source | `CraneDeck/CraneTower` (0.6,5.655,-4), cao1.6 m và `CraneJib`, dài6 m, đều không chặn tia xuyên tâm. | Tower/jib vật lý đúng hình hoặc đặt phần trang trí ngoài vùng chạm; giữ hành lang deck. Cable rất mảnh có thể cosmetic; không làm hàng rào dây vô hình. |
| D05 | P1 / runtime + ảnh | `GardenPoolRim` 5 ×0.3 ×4 m và mặt nước nâng trên terrace đều xuyên; đi vào không phản ánh bờ hồ nhìn thấy. | Làm bờ bốn cạnh + đáy nông hợp lý, hoặc hạ hồ flush với sàn và đổi hình bờ. Không đặt một collider đặc kín cả lòng hồ. Giữ lối đi quanh hồ, không ngầm thêm drowning hazard. |
| D06 | P1 / source; cần kiểm tra tiếp xúc khi sửa | Stair handrail/baluster/stringer visual-only theo chủ ý chống kẹt; mái dốc House là facade không collider phía trên mái phẳng có collider. | Không gọi tất cả là lỗi missing collision. Dời rail ra ngoài clearance, cắt/định hình đúng chỗ giao đường trước khi làm solid. Với mái House, xác định rõ mặt có thể đặt chân; không cho đứng trên hình mái nhưng vật lý ở mặt khác. Kiểm tra powered jump, camera và prop crossing. |
| D07 | P2 / ảnh đủ16 building + source | 8 building Đông/Tây dùng cùng counter và 3 shelf/goods; TownHall, NorthWest, NorthEast, GardenCafe chưa có nội thất đặc trưng. | Thiết kế bộ nội thất riêng theo bảng khu vực bên dưới; phải nhận ra chức năng không chỉ nhờ biển tên. |
| D08 | P2 / ảnh + source | Shop/School/House/Warehouse còn nhìn thấy nền cỏ xuyên suốt bên trong; tường trong tối/phẳng, cửa sổ chủ yếu là facade ngoài. | Sàn/threshold có chủ đích, chi tiết mặt trong và ánh sáng đọc được; đừng tự mở lỗ cửa sổ làm thay shelter. Sàn mới không thành bậc mắc capsule hoặc mặt sàn còn tồn tại sau collapse. |
| D09 | P2 / ảnh | GardenCafe nhìn ra ghế băng nằm trên trục tiếp cận; Civic/ngoại vi có khoảng lát/grass rộng nhưng ít công năng; Harbor rất thưa và đối xứng. | Tạo arrival pocket và bố cục phụ cạnh lối đi; dịch bench nếu sweep/đường thoát cần. Giữ khoảng trống có chủ đích, không lấp đầy chỉ để tăng số lượng đồ. |
| D10 | P1 / blind spot đã xác minh | Test garage hiện chỉ yêu cầu đến deck nên **đi xuyên kệ vẫn pass**; detail-collision chỉ có ít điểm mẫu, không bao hết furniture/crane/canopy. | Bổ sung contract “vật phải chặn” và “lối phải thông” độc lập, thay vì chỉ test route tới đích hoặc đếm collider. |

### Những điều không được gọi nhầm là bug

- 16 roof-center probes đều có support: **không có bằng chứng lỗ mái nguyên trạng ở tâm**.
- Ramp có overlap seam rất nhỏ để nối platform; không tự ý tách seam tạo khe rơi.
- Vạch đường, lát nền, plank, cargo rib, lá cây cao, window trim có thể không có
  collider riêng nếu mặt đỡ/khối chính đúng và không hứa hẹn một chỗ đứng khác.
- HarborBasin hiện là **nền nông đi được**, không phải biển sâu. Cần làm ngôn ngữ
  hình ảnh rõ hơn, không âm thầm đổi sang bơi/chết đuối.
- Garage deck mở không được giảm lực Tornado là lựa chọn hiện hành, được test rõ.
  `shelter` group không phải nguồn quyết định: Tornado dùng cover AABB; weather,
  meteor và UFO dùng physics rays khác nhau; Lightning không có roof exemption.
  House thiếu Tornado AABB là điểm cần giải thích/đối chiếu thiết kế, chưa mặc định
  là bug để thêm immunity. Giữ nguyên rule hazard trừ khi có scope riêng.
- Boundary/boardwalk chạm nhau ở mép chưa đủ để kết luận lỗi; chỉ chỉnh nếu hình
  tạo lời hứa có thể đi ra ngoài, hoặc capsule/camera thực tế bị kẹt.

## 3. Coverage toàn map và brief chi tiết theo khu

Tọa độ dùng world x/z; Bắc là -z. “Đề xuất” dưới đây **chưa được implement**.
Mỗi khu giữ đường chính và sightline telegraph; đặt đồ cạnh tường/ở pocket,
không đặt giữa arrival, cửa, đường chạy hoặc breakable panel.

### Toy Town — 112 ×112 m, không chỉ block trung tâm

| Khu / anchor | Đã thấy | Đề xuất sửa và làm giàu có chủ đích |
| --- | --- | --- |
| Plaza, road loop, spawn (0,7) | Nền/vạch đường có support; không gian thoáng; đồ nhỏ ít công năng. | Giữ spawn sạch; viền plaza, bảng định hướng có chữ, bin, cụm ghế/planter ở rìa, parking bays cho xe sẵn có. Curb thấp và crossing không tạo bậc vô hình. |
| Shop (-16,-13), mái và hai cửa | Counter/kệ ghost; canopy lệch collider; nội thất thưa, nền cỏ. | Sales counter có chân/mặt bàn, hàng hóa gom theo display, tủ kho, bảng hàng, sàn cửa hàng; clear north-south aisle và cửa sau. Canopy thống nhất vật lý, roof panel không bị đồ che. |
| School/Hall (16,-13) | Vách chia phòng solid; bàn/coat rack ghost; hành lang lọt lòng khoảng2.7 m (hai vách ±1.5, dày0.3), chưa đủ mục tiêu đường chính3 m. | Nới corridor khi bố trí lại; bàn-ghế/bảng/cubby/noticeboard rõ chức năng; sàn lớp khác hành lang; không làm lối giữa lớp thành hốc chết hoặc che cửa. |
| Garage (-15,15), gầm, deck, canopy, dốc | D01; gầm gần như trống, cột/canopy có support. | Giữ arrival4 m, dời kệ theo cạnh deck; toolbox/panel dụng cụ đặt vào service bay, wheel stop và paint bay đọc được. Gầm có nền/đánh số cột và một cụm bảo trì ngoài lối chạy. Không thêm xe động hoặc ép đi giữa khe cột. |
| House (-18,27), hai cửa và mái dốc | Đồ có công năng nhưng ghost, table gần đường giữa, nền cỏ; facade mái khác support. | Kitchen có cabinet/sink, bàn-ghế gọn, bed/pillow và sofa rõ cấu tạo; hành lang tránh table thật. Giải quyết mái theo D06; không thêm tầng mới. |
| Pocket Park (15,14), ramp/CRATE UP | Cây/bench/planter/rail có cấu trúc; đường crate boost cần bảo tồn. | Bổ sung viền bồn, bin, bảng park, tiểu cảnh thấp theo cụm; giữ ramp3 m, crate shove/mount và hai escape không bị rail/chậu mới cắt. |
| Bakery (-42,-22) | Cùng template như mọi shop; ghost counter. | Tủ bánh có tầng, khay/bánh toy gom mesh, quầy thu ngân và bảng menu; đặt display một bên, không làm hàng xếp chắn cửa. |
| Homes (-42,-7) | Template thương mại không diễn đạt nhà ở. | Sofa thấp, bàn nhỏ, bếp/kệ gia đình và thảm bằng decal/mesh phẳng; aisle xuyên nhà rõ, tránh sao chép House nguyên khối. |
| Workshop (-42,8) | Template shop, không có service identity. | Workbench, toolboard, cabinet, toolbox; không dùng hàng chục tool collider. Bố trí bench quay vào tường và service pocket ngoài trục. |
| Apartments (-42,23) | Một phòng8×8, không phải tòa nhiều tầng; template shop. | Làm sảnh apartment: mailbox, ghế chờ, bảng số căn, tủ bảo trì. Không hứa có cầu thang/tầng đi được nhưng dựng giả. |
| Library (42,-22) | Template shop, chưa có dãy sách đặc trưng. | Bookshelf theo cụm, bàn đọc thấp, book-return desk; không biến kệ thành mê cung, luôn nhìn được hướng cửa. |
| Clinic (42,-7) | Template shop, chưa có clinic identity. | Reception, bench chờ, một giường khám/cabinet y tế toy; ký hiệu có chữ, không lẫn HP pickup hoặc safe-zone bất tử. |
| Cafe (42,8) | Template shop. | Service counter, menu, coffee machine đơn giản, ít bàn-ghế theo pocket; ghế không rải khắp lối giữa. |
| Market (42,23) | Template shop. | Rack hàng, giỏ/thùng rau quả gom nhóm, checkout và bảng giá; không chặn cửa hoặc bậc nối roof stairs. |
| West/East terraces & roofwalks (x±42, z[-31,31]) | Hai dãy lặp silhouette; rail/vent/planter nhiều, connector có collider; roofs tâm kín. | Đổi nhịp facade/biển/awning theo chức năng, một số rooftop utility cluster có cấu tạo; giữ roofwalk3 m, landing, edge drop và đường không cần buff. Không rải clutter lên breakable panel. |
| Civic/TownHall (0,-45), stairs x0/±27 | Quảng trường lớn, hall rỗng, hàng cây/lamp lặp; nhiều mặt lát chưa có công năng. | Reception/info desk, ghế chờ, board của thị trấn; ngoài trời có civic focal point thấp và cụm ghế hai bên, giữ trục cầu thang vào hall trống. |
| Residence/NorthWest (-24,-45) | Nội thất trống. | Phòng sinh hoạt toy nhỏ, bàn/sofa/storage sát cạnh; phân biệt với apartment lobby. |
| Studio/NorthEast (24,-45) | Nội thất trống. | Bàn làm việc, easel/display và cabinet; props tĩnh, không tăng hệ tương tác. |
| Garden/Cafe/pond (z33–51) | Cafe rỗng; hồ ghost; hàng cây/bench theo nhịp đều; bench thẳng trục cửa Cafe. | Quầy cafe + bàn theo cụm, dời bench khỏi arrival, pergola/planter thấp có công năng, bờ hồ đúng D05; lối quanh hồ, garden stairs và promenade liên tục. |
| Perimeter, corners, hậu nhà, nối Bắc/Đông/Tây/Nam | Boundary liên tục; có dải rìa trống; mẫu giữa cửa không đủ chứng minh mọi khe/corner. | Theo§0: tái thiết biên cho Town mở rộng, thêm block/vòng ngoài nối thật; kiểm snap/đế/rail, không lấp rìa bằng props lặp để che lỗi. Backdrop không gợi cửa giả có thể mở. |

### Toy Harbor — 64 ×64 m — audit lịch sử, toàn bộ đề xuất tạm hoãn

| Khu / anchor | Đã thấy | Đề xuất sửa và làm giàu có chủ đích |
| --- | --- | --- |
| Warehouse (0,-18), hai cửa, roof/ramp | Rack/workbench/stack ghost, nền cỏ; roof panel có support. | Receiving/storage/workbench thành ba pocket, pallet/crate/barrel, safety board và sàn kho; door-to-door aisle mở, ray cover không còn phụ thuộc mesh giả. Không che roof panel. |
| CraneDeck (0,-2), ramp, dưới deck | Thân/cần cẩu ghost; silhouette nhìn xa như canopy hơn thiết bị cảng. | Base plate, tower có tiết diện rõ, jib/bracing/counterweight và hook readable; collider tower/jib đúng, cable cosmetic có chủ ý. Thêm cấu tạo chân deck nhưng không chắn ramp/edge exit; không crane simulation. |
| DockWest (-18,9) và DockEast (18,9) | Deck/plank/lamp/bollard/rail khá sạch nhưng gần như đối xứng/trống. | Một dock thiên receiving, một dock service: mooring cleat, rope coil sát bollard, pallet/barrel clusters và ký hiệu bay. Giữ landing ramp3 m và đầu gangway trống, không tạo một dock luôn tốt hơn khi Flood. |
| Gangway hai nửa (z9), basin (0,7) | Đường cao hẹp có chủ đích, breakable; basin xanh phẳng đi được. | End-cap/support joints và edge marking rõ; không làm hẹp cầu hay cho decor bắc cầu thay phần đã vỡ. Basin diễn đạt bể nông/maintenance apron, thêm mép và depth cue, không đổi thành nước chết. |
| CargoWest/East (±16,-16) | Khối có rib và lid, không nên thêm collider cho mọi rib. | Container doors/corner casting/ID và stack variation có support; đặt cargo phụ ngoài circulation. Không thêm đường roof access giả hoặc che mất lid breakage. |
| BoardwalkSouth/spawn (0,22) | Đủ rộng nhưng thưa, nhiều nền trống; boundary sát mép ngoài. | Signage cảng, bench/bin, service cart tĩnh hoặc cụm hàng cạnh rìa; giữ hai hướng tiếp cận dock/crane và spawn không bị đồ chặn. |
| Perimeter/corners/rear warehouse | Grass rộng, hai cây, ít ngữ cảnh cảng. | Dải service road, curb/paving transition, fence/backdrop toy và utility pocket; giữ sightline warning và đường vòng không mắc khe sát boundary. Không chỉ nhân bản kho/cargo để lấp đất. |

## 4. Chính sách collision và độ chi tiết

| Loại | Quy tắc triển khai đề xuất |
| --- | --- |
| Sàn, wall, ramp, mái đi được, cột, tower | Primitive/convex proxy đúng mặt tiếp xúc; mặt đỡ phẳng, kiểm tra seam và support. |
| Furniture/assembly lớn có thể chạm | Static collider theo khối công năng; tabletop/feet hợp lý, không hình trống mà collider bịt aisle. Collider và mesh cùng transform. |
| Rail | Solid nếu biểu đạt rào; đặt ngoài clearance và có khoảng thoát rõ. Nếu buộc non-solid, đổi hình thành edge trim/marking không giả làm barrier. |
| Mái cong/bờ hồ/mái dốc | Proxy có cấu tạo, không một AABB bao cả khoảng rỗng; bỏ collider cũ khi thay hình. |
| Vạch sơn, tile, trim, goods trên shelf, dây nhỏ, lá cao | Có thể cosmetic; không tạo bề mặt bước lên hoặc che hazard giả. Không spawn player/pickup dựa trên decorative mesh. |
| Breakable/collapse-owned detail | Đồ mới gắn owner/region rõ, support biến mất thì không để đồ/shape lơ lửng; restore đúng sau5 rematch. |

“Chi tiết” gồm: khối chính có công năng → cấu tạo thứ cấp → ít accent nhỏ.
Mỗi địa điểm có ít nhất một silhouette nội thất đặc trưng, chi tiết gắn vào nhau và
sàn/threshold phù hợp. Dùng shared mesh/material, MultiMesh/batching cho lặp nhỏ;
ưu tiên thêm hình có giá trị hơn thêm node/physics body. Không đặt tiêu chí số lượng
prop càng nhiều càng tốt; Town đã có3,006 visible mesh và1,253 enabled shape.

## 5. Milestone triển khai — checkbox phản ánh evidence hiện hành

### 13.1 — Town topology/expansion greybox và vật lý đúng hình (P0/P1)

- [ ] **13.1.0 Greybox:** thực hiện contract§0 trước khi khóa tọa độ/đồ chi tiết;
  footprint144 m candidate, compact frontage, connected neighborhoods, bridge/curb
  topology, collapse cuts, extents/anchors và đo controller route time.
- [x] **13.1.1 Garage arrival:** dời kệ/toolbox, collision mới, giữ4 m lane và landing.
- [x] **13.1.2 Existing furniture:** chỉ sửa Town, kiểm counter/desks/sofa/bed
  và toàn bộ8 district; không chỉ thêm một probe ở garage.
- [x] **13.1.3 Special geometry:** canopy cũ, hồ, rail/stairs và mái House;
  chốt mặt nào được bước lên, mặt nào là cosmetic và đổi hình nếu gây hiểu nhầm.
- [ ] **Gate:** test controller chứng minh furniture chặn, route thông; cả hai chiều,
  base/sprint/Speed/Jump, đẩy crate và hồi phục ragdoll không kẹt. Test dựa vào physical
  sweep/walk, không dựa vào tên node/count; giữ test hồi quy garage qua public behavior.
- [ ] **Gate:** map-safety, map-variety, detail-collision, prop-role-feasibility và
  terrain-collapse-routes; render Town garage/canopy/pool/bridge/curb trước–sau từ camera gameplay.

### 13.2 — Nội thất Town có bản sắc, không còn phòng rỗng/template (P2)

Phụ thuộc13.1. Làm một mẫu Shop/Workshop có floor, assembly và camera trước, rồi áp dụng
ngôn ngữ đó sang khu khác; không nhân bản cùng phòng với biển tên khác.

- [x] **13.2.1 Core:** Shop, School, House, garage gầm/deck.
- [x] **13.2.2 West:** Bakery/Homes/Workshop/Apartments, mỗi nơi đúng brief ở bảng.
- [x] **13.2.3 East:** Library/Clinic/Cafe/Market, giữ các connector và landing.
- [x] **13.2.4 North/South:** TownHall, Residence, Studio, GardenCafe.
- [x] **13.2.5 Added blocks:** bốn candidate service/community/garden/market building
  theo§0, interior riêng và hai kết nối thật; không tăng số lượng nếu chưa qua greybox.
- [ ] **Gate:** đủ15 building Town được kiểm hai cửa, interior sweep, mặt sàn, góc quay
  third-person và ảnh entrance + interior. Mỗi nơi có bố cục/silhouette riêng, không còn
  phòng được gắn nhãn có chức năng nhưng chỉ có tường trống. Không mở thêm tầng.

### 13.3 — Town ngoài trời liền mạch và có công năng (P2)

Phụ thuộc13.2; thực hiện theo plaza/roads → terrace/roofwalk → civic → park/garden → perimeter.

- [x] Sửa grounding/snap và joint của kiến trúc, stairs/rail/roofwalk/paving/curb.
- [x] Bổ sung cụm chức năng, signage, parking/service pockets theo bảng; phá nhịp lặp
  bằng bố cục và silhouette, không bằng hàng trăm màu/vật liệu mới.
- [ ] **Gate:** đường chính≥3 m, cửa≥1.8×2.2 m, hai escapes mỗi primary refuge;
  kiểm tra chéo/đổi hướng tại arrival, sát tường/cột và cạnh biên, không chỉ centerline.
- [ ] **Gate:** đo open-ground coverage theo footprint chướng ngại, giữ≥40%; render
  ground/interior/roof tại daylight, Flood và meteor/tornado telegraph overlap.

### 13.4 — Whole-Town route/collapse/crowd acceptance

Phụ thuộc13.3; **thay thế milestone Harbor đã hoãn**, không đánh dấu milestone cũ hoàn tất.

- [x] Mọi Town district/roof/stair/bridge có complete-route tests, không chỉ Shop/Hall.
- [x] Hai phía seam, pending/removed region và bridge broken không mất support ngoài warning.
- [ ]20-player spawn/turn/merge, refuge phân bố và base-walk route timing đạt§0;
  pickups không spawn trong đồ, đồ/collision restore sau5 rematch.
- [x] Ground/interior/roof camera và hazard telegraph overlap của Town được render/inspect.

### 13.5 — Regression, lifecycle và performance (không tự động ship)

- [x] Chạy lại map suites và full `tests/run_ui_regression.sh`; giữ strict script/runtime
  checks, ghi riêng shutdown resource diagnostics, không che lỗi bằng filter rộng.
- [x] Toy Town: intact, damaged/broken, collapse từng region và mọi mask hợp lệ,
  Flood escape từ mọi spawn group; không còn invisible support hay floating furniture.
- [x] Real ENet2/4/8/20 peers, five rematches: cùng collision/placement ở authority và
  client, không duplicate/lost props, power-up spawn không nằm trong đồ mới.
- [x] Harbor chỉ giữ regression không đổi hành vi nếu dùng helper chung; không thêm
  yêu cầu render/detail/collision fix Harbor vào scope Town.
- [ ] Lập baseline node/mesh/material/shape/draw-call/physics/frame-time trước–sau,
  cùng camera/resolution/renderer/player count. Profile20 peers; không tăng động-body
  cap để trang trí. Dùng batching trước khi cắt chi tiết có giá trị; không hứa60FPS từ
  llvmpipe. Native Windows/GPU/audio/real-player comprehension vẫn chưa xác minh.
- [x] Manifest/provenance cho asset thực sự thay/được thêm; đúng palette, shared material,
  import và license. `ENV_ConnectedDetailedTown_v005` ghi geometry project-authored.
- Ngoài scope hiện tại, chưa thực hiện: matching Windows/Linux PCK và standalone smoke;
  commit/push/package/release/deploy là bước riêng theo authorization, không tự suy từ plan.

## 6. Baseline kiểm thử và giới hạn kết luận

Các test cũ pass không phủ định D01–D06: chúng kiểm đường đi/survival hiện hành,
không bắt mọi thứ nhìn rắn phải rắn. Log phiên này nằm ở `.scratch/map-design-audit/`.

- `MAP_IDENTITY_OK checks=42`; `MAP_SAFETY_OK checks=233`;
  `PROP_ROLE_FEASIBILITY_OK checks=191`; `TERRAIN_COLLAPSE_ROUTES_OK checks=2818`,
  gồm18 controller walks và278 legal masks trên hai map. Bốn suite không có
  script/runtime diagnostic trong log phiên này.
- `MAP_VARIETY_OK checks=424` và `MAP_DETAIL_COLLISION_OK checks=82` nhưng
  **strict gate không sạch**: cả hai emit2 ObjectDB instance leak và1 resource-in-use
  diagnostic khi shutdown dù process exit0. Không có assertion/script lỗi trước marker;
  wrapper strict dừng ở variety, ba suite còn lại được chạy riêng sau đó. Lỗi cleanup
  được giữ lại, không đổi thành “all green”.
- `jq empty progress.json`, Markdown local-link/proposed-phase consistency và
  `git diff --check` pass. Đây là kiểm tra tài liệu, không phải gate map sửa.
- Audit ray/controller và39 ảnh chỉ ở map intact, Linux Compatibility/llvmpipe,
  Dummy audio. Chưa chứng minh mọi góc camera, mọi va chạm khi chen20 người,
  native GPU performance hoặc chất lượng trải nghiệm người thật.
- Điều tra packet-loss timeout trước đó giữ nguyên evidence và **đang hoãn**, không
  làm prerequisite cho việc xem/duyệt kế hoạch map; không tuyên bố đã sửa mạng.

**Điểm hoàn tất của lần yêu cầu này:** có audit cả hai map, findings có bằng chứng,
brief đủ từng khu và checklist có dependency/gate. Điểm hoàn tất của map sửa thật
chỉ có sau implementation và các gate13.1–13.5; hiện chưa đạt/chưa triển khai.

### Điểm vào source khi bắt đầu triển khai

- [Town/district/Harbor builders](../../game/main.gd#L2700),
  [stairs và building shell](../../game/main.gd#L3068),
  [canopy/detail collision](../../game/main.gd#L3252),
  [garage/interiors/Harbor kit](../../game/main.gd#L3451).
- [Map safety](../../tests/test_map_safety.gd),
  [detail collision](../../tests/test_map_detail_collision.gd),
  [map variety](../../tests/test_map_variety.gd),
  [prop feasibility](../../tests/test_prop_role_feasibility.gd),
  [collapse routes](../../tests/test_terrain_collapse_routes.gd).
