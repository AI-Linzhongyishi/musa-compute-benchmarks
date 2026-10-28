# MUSA Compute Benchmarks (musa-compute-benchmarks)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/Platform-Ubuntu%2022.04%20|%2024.04%20|%2026.04-orange.svg)]()
[![Hardware: Moore Threads MTT S80](https://img.shields.io/badge/GPU-MTT%20S80%20(16GB%20GDDR6)-red.svg)]()
[![MUSA SDK: 4.2+ / 4.3+](https://img.shields.io/badge/MUSA-SDK%20v4.2%20/%20v4.3-green.svg)]()

**musa-compute-benchmarks** 是全网首个专为摩尔线程（Moore Threads）国产高性能 GPU 打造的开源 GPGPU 通用计算与密码学哈希基准测试套件。

本项目填补了开源社区对国产 GPU 底层硬件显存吞吐、纯浮点 TFLOPS 及高并发加密哈希（SHA-256）算力评测的空白，不局限于传统 LLM 大模型推理，全方位评测 **PCIe 4.0/5.0 数据传输吞吐、GDDR6 显存带宽极限、FP32 单精度浮点峰值（TFLOPS）** 以及 **高并发密码学哈希计算吞吐（SHA-256 MH/s）**，并内置开箱即用的现代 `FindMUSA.cmake` 工具链。

---

## 📊 硬件实测对比基准（Benchmark Results）

测试基线硬件环境：同一台物理主机（Intel Core i5-14600KF + 16GB DDR5 6000MT/s + Ubuntu 26.04 LTS / Linux 7.0 内核）

### 1. 核心算力与密码学吞吐全面对比

| 硬件规格与基准测试项 | 摩尔线程 MTT S80 (16GB GDDR6) | NVIDIA Quadro P620 (2GB GDDR5) | NVIDIA RTX 5060 Ti 16GB (参考) | 对比与实测表现 |
| :--- | :--- | :--- | :--- | :--- |
| **GPU 架构** | 摩尔线程 MUSA 架构 (春晓核心) | NVIDIA Pascal (GP107) | NVIDIA Blackwell (GB206) | 国产首款自研 MUSA 架构 |
| **流处理器规格** | **4096 MUSA 核心 (32 SM)** | 512 CUDA 核心 (4 SM) | 4608 CUDA 核心 (36 SM) | **8.0x P620 计算单元规模** |
| **显存规格与位宽** | **16 GB GDDR6 / 256-bit** | 2 GB GDDR5 / 128-bit | 16 GB GDDR7 / 128-bit | **8.0x P620 容量 / 2.0x 物理位宽** |
| **显存有效带宽** | **323.93 GB/s** (Kernel 实测双向) | 80.0 GB/s (理论峰值) | 448.0 GB/s (理论峰值) | **4.05x P620 显存吞吐** |
| **PCIe 主机/设备传输** | H2D: **18.84 GB/s** / D2H: **19.59 GB/s** | PCIe 3.0 x16 (~12~13 GB/s) | PCIe 5.0 x8 | **1.55x P620 传输效率** |
| **FP32 浮点算力峰值** | **8.075 TFLOPS** (实测 3.35 Tera-ops) | 1.40 TFLOPS (官方理论峰值) | 23.70 TFLOPS | **5.77x P620 浮点算力** |
| **SHA-256 并发哈希 (v1)**| **810.75 MH/s** (52.4万并发线程) | **442.60 MH/s** (Hashcat 模式 1400) | ~5,950 MH/s | **1.83x P620 纯哈希速率** |
| **SHA-256 并发哈希 (v2)**| **873.92 MH/s** (104.8万并发线程) | - | - | **布尔化简 + 16字环形滚动窗口** |
| **SHA-256 内建指令 (v3)**| **873.90 MH/s** (104.8万并发线程) | - | - | **编译器 `__builtin_rotateright32` 原语** |
| **密码候选快路径 (v4)**| **931.87 MH/s (9.32 亿组/秒)** | - | - | **零项消除 + 常量折叠快路径 (+15.0%)** |
| **双路指令并行 (v5)**  | **924.64 MH/s (9.25 亿组/秒)** | - | - | **2-Way ILP 算术流水线延迟隐藏** |
| **Hashcat 逆向增强 (v6)**| **1066.01 MH/s (10.66 亿组/秒)** | - | - | **Meet-in-the-Middle 逆向截断 (+31.5% / 2.41x P620)** |

---

## 🚀 性能优化演进（Optimization Roadmap）

本项目针对摩尔线程「春晓」架构（32 个 SM、4096 个流处理器）进行了深度底层算子调优演进：

### V1 基线版本（Generic MUSA Baseline）：
- 采用通用 SHA-256 算法实现，每个线程计算单组消息。
- 524,288 活跃线程并发，达到 **810.75 MH/s**（相对 Quadro P620 提升 **1.83 倍**）。

### V2 寄存器与布尔优化（Circular Register Window & Boolean Reduction）：
1. **布尔代数化简（Boolean Simplification）**：
   - 将标准选择函数 $Ch(x,y,z) = (x \land y) \oplus (\neg x \land z)$ 化简为等价的 $z \oplus (x \land (y \oplus z))$，底层 ALU 指令从 4 条降至 3 条；
   - 将多数函数 $Maj(x,y,z)$ 指令从 5 条降至 4 条，全流程 64 轮变换每哈希立省 64 条指令。
2. **16 字环形滚动寄存器窗口（Circular Register Window）**：
   - 将原本静态展开的 `W[64]` 数组大幅压缩为 `w[16]`，通过位掩码 `w[i & 15]` 循环复用，消除了寄存器向显存溢出（Local Memory Spill）的延迟。
3. **百万级并发调度扩展**：
   - 活跃 GPU 线程数提升至 **1,048,576**，吞吐升至 **873.92 MH/s**。

### V3 编译器原语（Hardware Intrinsics）：
- 引入 LLVM Clang 底层循环右移原语 `__builtin_rotateright32`，保证编译器直接生成硬件单周期 `ROR` 指令。

### V4 密码候选快路径（Zero-Term Elimination & Constant Folding）：
1. **零项消去（Zero-term Elimination）**：
   - 在真实字典与密码候选场景（如 12 字节以内口令），数据块第 4 至第 14 组字全部恒为 `0x00000000`。
   - 剔除无意义的加法运算，每轮节省 1 条 32 位加法指令。
2. **消息扩展常量折叠（Compile-time Constant Folding）**：
   - 提前预计算轮次 16 至 26 的确定性常数项，实测吞吐突破 **931.87 MH/s（9.32 亿组/秒）**。

### V5 双路指令级并行（Dual-ILP Latency Hiding）：
- 探索单线程双密码候选交织（2-Way Interleaved Candidate Evaluation），利用无数据依赖的两组口令哈希指令填补流水线读后写（RAW Hazard）延迟，实测达到 **924.64 MH/s**。

### V6 Hashcat 逆向会师增强版（Meet-in-the-Middle Reverse Early Abort）：
- **吸收借鉴工业级 Hashcat 7.1.2 底层 OpenCL 内核架构**：
  1. **双向会师逆向早期截断（Meet-in-the-Middle）**：在主机端预先将目标哈希进行 4 步反向逆推求出中间状态 `d_rev`；GPU 正向计算在**第 56 轮**直接进行碰撞比对，99.9999% 的不匹配候选立即放弃，彻底省去后半段最后 8 轮计算！
  2. **极简布尔逻辑与循环左移映射**：采用 Hashcat 专属的 `SHA256_F0` / `SHA256_F1` 优化定义，结合硬件左旋原语加速。
- **实测成果**：单轮计算时间首次压进 1 秒大关（**983.64 ms**），吞吐量历史性突破 10 亿大关，达到 **1066.01 MH/s（10.66 亿组候选/秒）**，较 v1 基线净增 **+31.5%**，达到亮机卡 Quadro P620 的 **2.41 倍**！

---

## 🛠️ 项目工程结构

```text
musa-compute-benchmarks/
├── CMakeLists.txt              # 根 CMake 构建配置文件 (集成 FindMUSA)
├── cmake/
│   └── FindMUSA.cmake          # 自研 MUSA 工具链与 mcc 编译器自动检测模块
├── benchmarks/
│   ├── common.h                # 通用高精度计时器与 MUSA 设备信息诊断
│   ├── bandwidth_bench.mu      # H2D / D2H / D2D 显存与 PCIe 吞吐基准测试
│   ├── compute_flops_bench.mu  # FP32 纯浮点算力峰值基准测试 (v1)
│   ├── compute_flops_bench_v2.mu # FP32 高密度 FMA 浮点压测 (v2)
│   ├── crypto_hash_bench.mu    # SHA-256 并发哈希测试 (v1 基线)
│   ├── crypto_hash_bench_v2.mu # SHA-256 环形寄存器布尔优化版 (v2)
│   ├── crypto_hash_bench_v3.mu # SHA-256 编译器硬件原语版 (v3)
│   ├── crypto_hash_bench_v4.mu # SHA-256 零项消去与常量折叠快路径 (v4)
│   ├── crypto_hash_bench_v5.mu # SHA-256 双路指令级并行流水线版 (v5)
│   └── crypto_hash_bench_v6.mu # SHA-256 Hashcat 逆向会师增强版 (v6 破10亿大关)
├── scripts/
│   └── run_benchmarks.sh       # 一键全套编译并执行基准测试脚本
├── LICENSE                     # MIT 开源许可证
└── README.md                   # 完整测试报告与中英文架构说明
```

---

## ⚡ 快速编译与运行（Build & Run）

### 环境要求
- 操作系统：Ubuntu 20.04 / 22.04 / 24.04 / 26.04 LTS
- 硬件：摩尔线程 MTT S80（或其他 MUSA 架构 GPU）
- 软件栈：MUSA SDK v4.2+ / v4.3+，CMake 3.18+，GCC 11+

### 1. 编译全部基准测试项
```bash
git clone https://github.com/AI-Linzhongyishi/musa-compute-benchmarks.git
cd musa-compute-benchmarks

mkdir -p build && cd build
cmake ..
make -j$(nproc)
```

### 2. 运行 Hashcat 增强版极速基准测试 (v6)
```bash
# 运行突破 10 亿大关的 v6 Hashcat 增强测试
sudo ./build/crypto_hash_bench_v6
```

---

## 📄 许可证（License）
本项目采用 [MIT License](LICENSE) 协议开源。欢迎全球开发者提交 Issue 与 PR 共同完善摩尔线程 MUSA 开源生态！
