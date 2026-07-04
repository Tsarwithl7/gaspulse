<div align="center">

# OilPulse

**一款轻量、原生、本地优先的 macOS 能源价格监控工具。**

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20Swift%20Charts-green)
![Status](https://img.shields.io/badge/status-MVP-yellow)

[English](README.md) | **简体中文**

</div>

---

## 项目简介

**OilPulse** 是一个用于观察能源市场变化的轻量级 macOS 应用。它以原生小组件式界面展示 **Brent（布伦特）** 与 **WTI（西德州中质原油）** 的最新价格、涨跌幅和近期趋势，让关键行情始终保持在一键可达的位置。

应用采用**本地优先**的设计：无需打开浏览器，也不依赖重型后台服务；行情记录保存在本机 SQLite 数据库中，在网络不可用时仍可查看最近一次有效数据。

## 为什么做 OilPulse

原油价格是能源产业链中较为领先的市场信号，但它并不会立即、等比例地反映到加油站零售价。炼化成本、汽油期货、库存、税费和地区供需都会影响最终泵价。

OilPulse 的目标不是预测某一天一定涨或跌，而是把分散的价格变化整理成一个清晰、低干扰的观察窗口，帮助用户：

- 快速了解 Brent 与 WTI 当前处于什么价位和趋势
- 及时发现显著波动，为能源市场研究或日常决策提供参考
- 在未来接入 RBOB、裂解价差和地区泵价后，进一步观察“原油 → 成品油 → 零售价”的价格传导

对于个人用户，它可以作为加油时机的辅助信息，但不承诺每次都能带来实际节省；对于研究者、能源从业者和车队管理者，它也可以作为一个可扩展的本地行情观察基础。

## 功能特性

- **Brent** 与 **WTI** 最新价格并排展示
- 涨跌额与涨跌幅（绿涨 ↑ / 红跌 ↓）
- **1 天 / 1 周 / 1 月** 趋势图
- 打开即自动刷新 + 定时刷新（15 / 30 / 60 分钟）
- 普通手动更新与**强制更新**（忽略冷却）
- 本地 **SQLite** 缓存——离线时展示最近一次有效数据
- 清晰的状态指示：正常 / 缓存 / 离线 / 失败
- 可选开机自动启动

## 技术栈

| 模块 | 技术 |
|------|------|
| 开发语言 | Swift |
| 界面 | SwiftUI + Swift Charts |
| 网络请求 | URLSession（Yahoo Finance） |
| 本地缓存 | SQLite |
| 偏好设置 | UserDefaults / AppStorage |
| 开机启动 | macOS Service Management |
| 构建 | Swift Package Manager |

## 构建与运行

环境要求：**macOS 14 及以上**，以及 **Swift 工具链**（Xcode 或命令行工具）。

```bash
# 克隆仓库
git clone https://github.com/Tsarwithl7/oilpulse.git
cd oilpulse

# 构建 release 版 .app
bash build.sh

# 启动
open OilPulse.app
```

如果首次启动时 macOS 因为应用未签名而拦截，运行：

```bash
xattr -cr OilPulse.app && open OilPulse.app
```

## 项目文档

- [产品需求文档](product-requirements.md)

## 免责声明

本项目展示的数据仅供个人信息参考，可能存在延迟或误差，**不构成**任何投资或交易建议。
