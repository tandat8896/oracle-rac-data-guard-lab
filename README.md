# Oracle DBA Homelab — RAC 19c, Data Guard, Query Tuning

Lab Oracle DBA tự dựng từ đầu trên máy chủ NixOS: cụm **Oracle RAC 19c hai node** chạy trên
KVM/libvirt, hệ thống **Data Guard physical standby** có Fast-Start Failover, và một mạch
nghiên cứu **tối ưu truy vấn SQL** trên Oracle 19c.

Mỗi runbook ở đây là log của một phiên làm việc thật — đúng những lệnh đã chạy, đúng lỗi đã gặp
(`INS-08101`, `INS-35971`, `ORA-1017`, `ORA-00922`), và cách khắc phục thực sự có tác dụng.
Không có phần nào chép lại từ tài liệu.

**Tác giả:** Ngô Tấn Đạt

---

## Video minh chứng

[![Kết quả cấu hình cụm Oracle 19c RAC hai node](https://img.youtube.com/vi/-eH738r5fRQ/maxresdefault.jpg)](https://www.youtube.com/watch?v=-eH738r5fRQ)

**[Show Result: Oracle 19.0.0 RAC two-node cluster configuration](https://www.youtube.com/watch?v=-eH738r5fRQ)**

Video ghi lại kết quả cấu hình của cụm sau khi hoàn thành, kiểm tra trạng thái trên cả hai node.

---

## Kiến trúc lab

```text
                       Máy chủ NixOS (chỉ làm hypervisor)
                       libvirt / KVM · không cài Oracle trên host
    ┌──────────────────────────────────────────────────────────────────┐
    │                                                                  │
    │   ┌────────────────────┐          ┌────────────────────┐         │
    │   │  rac1              │          │  rac2              │         │
    │   │  Oracle Linux      │◄────────►│  Oracle Linux      │         │
    │   │  Grid 19c + DB 19c │  private │  Grid 19c + DB 19c │         │
    │   │  racdb1            │ 10.10.10 │  racdb2            │         │
    │   └─────────┬──────────┘          └──────────┬─────────┘         │
    │             │                                │                   │
    │             └───────────┬────────────────────┘                   │
    │                         ▼                                        │
    │              ┌──────────────────────┐                            │
    │              │  Lưu trữ ASM chia sẻ │                            │
    │              │  +OCRVOTE  (10 GB)   │  raw .img, virtio shared   │
    │              │  +DATA     (30 GB)   │  tên thiết bị cố định udev │
    │              │  +FRA      (30 GB)   │                            │
    │              └──────────┬───────────┘                            │
    │                         │ redo transport                         │
    │                         ▼                                        │
    │              ┌──────────────────────┐                            │
    │              │  stdby1 (racdb_s)    │  Data Guard physical       │
    │              │  MOUNTED / MRP       │  standby + observer FSFO   │
    │              └──────────────────────┘                            │
    └──────────────────────────────────────────────────────────────────┘
```

Cơ sở dữ liệu RAC `racdb` chạy active-active (hai instance `racdb1` / `racdb2`) với SCAN listener,
VIP, và một PDB (`pdb1`) chứa schema HR.

---

## Cấu trúc thư mục

```text
.
├── docs/
│   ├── rac/            19 runbook — dựng cụm theo từng bước
│   ├── dataguard/       6 runbook — standby, broker, FSFO, flashback
│   └── query-tuning/   19 tài liệu nghiên cứu + lab chạy được
├── configs/
│   └── node_files/     cấu hình lấy từ rac1, rac2, stdby1
├── scripts/            script nạp dữ liệu và môi trường Nix
├── labs/               SQL mô hình hoá dữ liệu và schema ngân hàng
└── media/
    └── screenshots/    ảnh chụp terminal trong quá trình dựng lab
```

---

## docs/rac — dựng cụm

| Bước | Runbook | Nội dung |
|-----:|---------|----------|
| 01 | [Mạng private](docs/rac/STEP-01-RAC-PRIVATE-NETWORK.md) | mạng libvirt `rac-priv` tách riêng cho interconnect |
| 02 | [Đĩa chia sẻ](docs/rac/STEP-02-RAC-SHARED-DISKS.md) | tạo disk image cho ASM, chuyển qcow2 sang raw |
| 03 | [Tạo máy ảo](docs/rac/STEP-03-RAC-CREATE-VMS.md) | dựng rac1 / rac2 trên KVM |
| 04 | [Gắn đĩa ASM chia sẻ](docs/rac/STEP-04-RAC-ATTACH-SHARED-ASM-DISKS.md) | đĩa virtio `shareable` gắn vào cả hai node |
| 05 | [Mạng và hosts](docs/rac/STEP-05-RAC-NETWORK-HOSTS.md) | đặt tên public / private / VIP / SCAN |
| 06 | [Chuẩn bị hệ điều hành](docs/rac/STEP-06-RAC-OS-PREREQS.md) | user, group, kernel parameter, limits, SSH equivalence, đồng bộ thời gian |
| 07 | [Udev cho đĩa ASM](docs/rac/STEP-07-RAC-ASM-DISK-UDEV.md) | cố định tên thiết bị để tồn tại qua reboot |
| 08 | [Stage phần mềm](docs/rac/STEP-08-RAC-STAGE-ORACLE-SOFTWARE.md) | đưa Grid home và DB home vào `/u01` |
| 09 | [Grid Infrastructure](docs/rac/STEP-09-RAC-GRID-INSTALL.md) | `gridSetup.sh`, `runcluvfy`, đưa ASM `+OCRVOTE` online — bước dài nhất |
| 10 | [Database home](docs/rac/STEP-10-RAC-DB-INSTALL.md) | cài phần mềm DB (software-only) trên cả hai node |
| 11 | [DBCA](docs/rac/STEP-11-RAC-DBCA-CREATE-DATABASE.md) | tạo cluster database `racdb` |
| 13 | [Tắt an toàn](docs/rac/STEP-13-RAC-SAFE-SHUTDOWN.md) | thứ tự dừng đúng cho một stack RAC |
| 14 | [Cold backup](docs/rac/STEP-14-RAC-COLD-BACKUP.md) | sao lưu mức file và mức máy ảo |
| 15 | [RMAN cơ bản](docs/rac/STEP-15-RAC-RMAN-BASICS.md) | online backup và validate, ghi vào `+FRA` |
| 17 | [Quy trình khởi động / tắt](docs/rac/STEP-17-RAC-STARTUP-SHUTDOWN-GUIDE.md) | vận hành hằng ngày |

Tài liệu bổ trợ: [`STEP-00-RAC-QUICK-REFERENCE.md`](docs/rac/STEP-00-RAC-QUICK-REFERENCE.md)
(biến môi trường, bảng đăng nhập, checklist khởi động),
[`STEP-00-RAC-COMMANDS-EXPLORE.md`](docs/rac/STEP-00-RAC-COMMANDS-EXPLORE.md), và
[`INDEX.md`](docs/rac/INDEX.md) — nhật ký theo ngày ghi lại cái gì hỏng và đã sửa ra sao.

---

## docs/dataguard — physical standby và Fast-Start Failover

| Runbook | Nội dung |
|---------|----------|
| [STEP-12 Data Guard standby](docs/dataguard/STEP-12-RAC-DATAGUARD-STANDBY.md) | dựng standby bằng RMAN `duplicate ... for standby`, cấu hình broker và redo transport |
| [STEP-16 Xử lý sự cố FSFO](docs/dataguard/STEP-16-RAC-FSFO-TROUBLESHOOTING.md) | vì sao chạy `orapwd` riêng trên từng node lại gây `ORA-1017` — salt khác nhau, nên password file bắt buộc phải *sao chép* chứ không tạo lại |
| [Runbook Data Guard](docs/dataguard/README-DATAGUARD-RUNBOOK.md) | quy trình vận hành hằng ngày |
| [Runbook FSFO và Flashback](docs/dataguard/README-FSFO-FLASHBACK-RUNBOOK.md) | Fast-Start Failover kết hợp Flashback Database, reinstate lại primary đã hỏng |
| [Kiểm tra hệ thống](docs/dataguard/README-DATAGUARD-CHECK-2026-05-25.md) | xác nhận standby thực sự đang apply redo |
| [Lab kiểm chứng](docs/dataguard/LAB-DATAGUARD-INSERT.md) | chứng minh replication chạy thông từ đầu đến cuối |

---

## docs/query-tuning — tối ưu SQL trên Oracle 19c

| Tài liệu | Chủ đề |
|---|---|
| [01 Execution plan](docs/query-tuning/docs/01_execution_plan.md) | đọc và tin được một execution plan |
| [02 Optimizer statistics](docs/query-tuning/docs/02_optimizer_statistics.md) | histogram, data skew |
| [03 Join operations](docs/query-tuning/docs/03_join_operations.md) | các thuật toán join, chọn sai driving table |
| [04 Sort merge join](docs/query-tuning/docs/04_sort_merge_join.md) | TempSpc và disk sort |
| [05 Composite index](docs/query-tuning/docs/05_composite_index.md) | thứ tự cột quyết định hiệu năng |
| [06 Index bị suppress](docs/query-tuning/docs/06_index_suppress.md) | những gì khiến Oracle bỏ qua index |
| [07 Partitioning, ACS, parallel](docs/query-tuning/docs/07_partitioning_acs_parallel.md) | Adaptive Cursor Sharing |
| [08 Runtime diagnostics](docs/query-tuning/docs/08_sql_runtime_diagnostics.md) | tìm top SQL, đọc plan thật, wait event |
| [09 AWR và ASH](docs/query-tuning/docs/09_awr_ash_performance_report.md) | Top Events, Top SQL, DB Time |
| [10 Lock và blocking session](docs/query-tuning/docs/10_lock_blocking_session.md) | row lock contention |
| [11 SPM và Tuning Advisor](docs/query-tuning/docs/11_sql_plan_management_tuning_advisor.md) | baseline, chống plan regression |
| [12 Thuật toán optimizer](docs/query-tuning/docs/12_optimizer_algorithms.md) | cardinality, selectivity, access path |
| [13 Buffer cache](docs/query-tuning/docs/13_buffer_cache_flow.md) | LIO/PIO, clustering factor |
| [14 Query transformation](docs/query-tuning/docs/14_subquery_query_transformation.md) | semi/anti join, CTE |

Phần tinh chỉnh bộ nhớ (SGA và PGA) nằm trong `docs/query-tuning/docs/memory-tuning/`. Các script
lab trong `docs/query-tuning/labs/` sinh bảng cỡ khoảng một triệu dòng để khác biệt giữa các plan
là thật, không phải lý thuyết.

Áp dụng trên dữ liệu thật ở tài liệu 15 đến 19: [lab thực hành với bộ dữ liệu thương mại điện tử
Olist](docs/query-tuning/docs/15_olist_practice_lab.md), sau đó là
[khám phá dữ liệu điện mặt trời](docs/query-tuning/docs/16_solar_data_exploration.md),
[kiểm định tương quan](docs/query-tuning/docs/18_correlation_test.md) và
[phân tích phân phối sản lượng](docs/query-tuning/docs/19_eda_energy_distribution.md) — chạy trực
tiếp trong database. [`ORACLE_PRODUCTION_INCIDENTS.md`](docs/query-tuning/docs/ORACLE_PRODUCTION_INCIDENTS.md)
tập hợp các tình huống sự cố dạng production và cách chẩn đoán.

---

## configs, scripts, labs

**`configs/node_files/`** — cấu hình thật lấy từ `rac1`, `rac2` và `stdby1`: `/etc/hosts`,
`sysctl.d`, `limits.d`, udev rule cho ASM, `listener.ora`, `tnsnames.ora`, `sqlnet.ora`, `oratab`,
shell profile, cùng thư mục `osinfo/` (`crs-status`, `lsblk`, `ip addr`) chụp riêng cho từng node.

**`scripts/`** — `load_data.py` và `load_weather_type.py` để nạp dữ liệu vào database, và
`shell.nix` dựng môi trường chạy.

**`labs/`** — SQL mô hình hoá dữ liệu (quan hệ metadata, profiling dựa trên statistics, lấy mẫu,
quan hệ nhiều-nhiều ba bảng) và schema ngân hàng.

---

## Ảnh chụp màn hình

Thư mục `media/screenshots/` chứa ảnh terminal chụp trong lúc dựng lab: `runcluvfy` chạy đạt,
`gridSetup.sh` đang cài, SSH equivalence giữa hai node, đĩa ASM hiện ra trong `lsblk` trên cả hai
máy ảo, DBCA tạo `racdb`, VIP lên online, và quá trình trace các lỗi khi cài Grid.

---

## Bảo mật và bản quyền

Đây là môi trường lab. Toàn bộ thông tin đăng nhập trong các tài liệu đã được thay bằng
`<REDACTED_PASSWORD>`. Các địa chỉ IP đều thuộc dải private RFC 1918 dùng cho lab —
`10.10.10.0/24` cho interconnect, `192.168.122.0/24` cho mạng libvirt — và tên host chỉ phân giải
được qua file `/etc/hosts` của từng node.

Phần mềm Oracle trong lab được sử dụng theo **Oracle Technology Network Developer License** —
giấy phép cho phép dùng miễn phí vào mục đích *developing, testing, prototyping và demonstrating*,
không dùng cho production, xử lý dữ liệu nghiệp vụ hay môi trường phát triển dùng chung.
Xem điều khoản đầy đủ tại
[oracle.com/downloads/licenses/standard-license.html](https://www.oracle.com/downloads/licenses/standard-license.html).

Repo này **không chứa bất kỳ phần mềm Oracle nào**. Bộ cài, phần mềm đã stage, file image máy ảo và
các file lấy từ `$ORACLE_HOME` đều bị loại, vì giấy phép cấm phân phối lại: `root.sh`,
`gridSetup.sh`, `runInstaller`, `runcluvfy.sh`, các file response, file `.mk`, file mẫu `init.ora`
và unit `oracle-ohasd.service` đều được chặn trong `.gitignore`. Chỉ tài liệu, cấu hình và ảnh chụp
do tác giả tự tạo mới được commit.
