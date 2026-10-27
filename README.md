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

---

## 🚀 性能优化演进（Optimization Roadmap）

### V2 深度优化核心特性：
1. **布尔代数化简（Boolean Simplification）**：
   - 将标准选择函数 $Ch(x,y,z) = (x \land y) \oplus (\neg x \land z)$ 化简为等价的 $z \oplus (x \land (y \oplus z))$，底层 ALU 指令从 4 条降至 3 条；
   - 将多数函数 $Maj(x,y,z)$ 指令从 5 条降至 4 条，全流程 64 轮变换每哈希立省 64 条指令。
2. **16 字环形滚动寄存器窗口（Circular Register Window）**：
   - 将原本静态展开的 `W[64]` 数组大幅压缩为 `w[16]`，通过位掩码 `w[i & 15]` 循环复用，消除了寄存器向显存溢出（Local Memory Spill）的延迟。
3. **百万级并发调度扩展**：
   - 将活跃 GPU 线程数从 524,288 翻倍提升至 **1,048,576**，充分填满 S80 32 个 SM 的硬件 CCB 队列。

---

## 🛠️ 项目工程结构

```text
musa-compute-benchmarks/
├── CMakeLists.txt              # 根 CMake 构建配置文件
├── cmake/
│   └── FindMUSA.cmake          # 现代化 MUSA SDK 查找模块与 musa_add_executable 宏
├── benchmarks/
│   ├── common.h                # 纳秒级高精度计时器与硬件参数探测器
│   ├── bandwidth_bench.mu      # PCIe 4.0/5.0 与 323+ GB/s 显存压力带宽测试
│   ├── compute_flops_bench.mu  # 4096 核心饱和 FMA 浮点 TFLOPS 测试 (v1)
│   ├── compute_flops_bench_v2.mu # 零延迟流水线 FMA 浮点测试 (v2)
│   ├── crypto_hash_bench.mu    # NIST SHA-256 哈希基准测试 (v1 Baseline)
│   └── crypto_hash_bench_v2.mu # 布尔化简与环形寄存器 SHA-256 测试 (v2 Deeply-Optimized)
├── scripts/
│   └── run_benchmarks.sh       # 一键全自动化编译与多版本顺序评测脚本
└── README.md                   # 项目工程说明文档
```

---

## ⚡ 快速上手与运行

### 1. 克隆代码与一键编译
```bash
git clone https://github.com/AI-Linzhongyishi/musa-compute-benchmarks.git
cd musa-compute-benchmarks

mkdir build && cd build
cmake ..
make -j$(nproc)
```

### 2. 运行基准套件
```bash
# 一键运行全部 V1 与 V2 评测：
sudo ./scripts/run_benchmarks.sh

# 或单独执行特定测试：
cd build
sudo ./bandwidth_bench          # 显存与 PCIe 带宽实测
sudo ./compute_flops_bench      # FP32 浮点算力 (8.07 TFLOPS)
sudo ./crypto_hash_bench        # SHA-256 v1 (810 MH/s)
sudo ./crypto_hash_bench_v2     # SHA-256 v2 (874 MH/s)
```

---

## 🧩 如何在你的项目中使用 `FindMUSA.cmake`？

本项目开源提供的 `cmake/FindMUSA.cmake` 支持将摩尔线程 MUSA 工具链无缝集成进现代 CMake 工程：

```cmake
# 将 cmake 目录加入模块搜索路径
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# 探测并引入 MUSA
find_package(MUSA REQUIRED)

# 使用 musa_add_executable 宏一键编译 .mu 文件
musa_add_executable(my_kernel_app src/my_kernel.mu)
```

---

## 📜 许可证 (License)

本项目采用 [MIT 许可证](LICENSE) 开源，欢迎提交 Issue 与 PR 共同完善摩尔线程 MUSA 开发者生态！
