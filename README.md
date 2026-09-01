# dsh-plugin-pet 🐾

**A Codex-style desktop pet for [DeepSeek Harness (DSH) Desktop](https://github.com/deepseek-ai/deepseek-harness) — living in your sidebar, reacting to your agent sessions.**

为 DSH Desktop 打造的 Codex 风格桌宠插件：宠物住在侧栏底部，跟随你的 agent 会话状态变换动作，会在窗口底部散步、跳跃提醒你查看新回复，可拖拽到任意位置。

> An English summary: this plugin renders an animated pet avatar in the DSH sidebar footer. It implements the OpenAI Codex pet sprite contract (8×9 atlas, official per-row animation timings), wanders along the window floor, and mirrors session state (idle / working / waiting / new reply). Bring your own sprite from `~/.codex/pets/` or any transparent sprite grid.

---

## 功能一览

| 能力 | 说明 |
|---|---|
| 🎬 官方契约动画 | 识别 Codex 宠物契约表（1536×1872、8列×9行、192×208/格），按官方行语义与逐帧毫秒数播放 |
| 🚶 自动散步 | 沿窗口底部随机漫步（running-left/right 行），随机停顿、边界掉头 |
| 📨 新回复提醒 | agent 回复完成后 ~60 秒内未读 → 跳跃 + 红点 + 气泡；点击宠物确认 |
| 🖱️ 拖拽安家 | 按住拖到窗口任意位置松手即住下 |
| ⏯️ 双击开关 | 300ms 内双击 = 冻结/恢复散步（localStorage 持久化） |
| 🧠 状态机 | sleep（无会话）/ idle / working（绿点）/ waiting（审批提问，蓝点）/ notify（红点） |
| ♿ 无障碍 | 系统开启「减弱动态效果」时显示官方静态帧 |
| 🔄 一键换宠 | 从 `~/.codex/pets/` 或任意精灵表自动测量网格并重建 |

## 环境要求

- [DSH Desktop](https://github.com/deepseek-ai/deepseek-harness)（DeepSeek Harness 桌面版）
- macOS（构建链使用系统自带 `sips` 做 WebP→PNG 转换）
- `node`（构建）与 `python3`（安装补丁；缺失时跳过 YAML 校验）
- 一份宠物素材（见下文）

## 快速开始

```bash
git clone https://github.com/Dreamshe-92/dsh-plugin-pet.git
cd dsh-plugin-pet

# 安装（自动选取 ~/.codex/pets/ 下的第一个宠物）
bash install.sh

# 或指定宠物
bash install.sh --pet xiaowa
```

然后 **完全退出 DSH Desktop（Cmd+Q）并重新打开**。宠物会出现在左侧边栏底部。

> 本仓库**不包含**任何精灵图素材——`client.js` 是安装时从你本地宠物构建的产物（已 gitignore）。

## 宠物素材从哪来

**方式一：Codex 宠物目录（推荐）**

`~/.codex/pets/<name>/{pet.json, spritesheet.webp}` 是 OpenAI Codex 的本地自定义宠物格式。已有 Codex 宠物的直接：

```bash
bash switch_pet.sh <name>        # 按名字子串匹配
```

**方式二：用 hatch-pet skill 生成**

[openai/skills](https://github.com/openai/skills/tree/main/skills/.curated/hatch-pet) 中的 hatch-pet skill 可以从角色概念/品牌生成完整契约表（`pets/<name>/` 产出），拿来即用，动画语义自动对齐。

**方式三：任意精灵表**

透明背景、等距网格的 sprite sheet（webp/png）：

```bash
bash switch_pet.sh /path/to/sheet.webp
# 不透明背景或网格不均时手动指定：
bash switch_pet.sh /path/to/sheet.jpg --cols 8 --rows 9 --size 96
```

## Codex 宠物契约

官方契约表（1536×1872）会被自动识别为 `contract` 模式，按行播放：

| 行 | 状态 | 插件映射 |
|---|---|---|
| 0 | idle（呼吸/眨眼，6 帧，280/110/110/140/140/320ms） | idle；sleep 为其 3× 慢放 |
| 1/2 | running-right / running-left（8 帧） | 散步（无左行时镜像） |
| 3 | waving（4 帧） | 出场打招呼 |
| 4 | jumping（5 帧） | notify 新回复 |
| 6 | waiting（6 帧） | waiting 等审批/提问 |
| 7 | running（专注干活，6 帧） | working |

非契约表自动退回 `simple` 模式（整表匀速循环 + CSS 情绪动画）。

## 常见问题

**装完重启后看不到宠物？**
1. 检查侧栏是否展开、滚到底部；
2. `curl -s http://127.0.0.1:<端口>/plugins/dsh-plugin-pet/client.js | head -c 100`（端口见 DSH 窗口地址）确认 200；
3. 查启动日志：`grep -i pet ~/Library/Application\ Support/DSH\ Desktop/logs/dsh-$(date +%Y-%m-%d).log`；
4. patch 校验：`cat ~/.dsh/profiles/desktop/cordis.patch.yml` 应含 `dsh-plugin-pet` 行。

**为什么装在两个 profile？** DSH Desktop 实际组装 `desktop` profile，`web` profile 一并打补丁以兼容 CLI 场景；patch 采用 YAML 安全的文本手术并带校验。

**换宠物/调大小后要重启吗？** 不用。构建产物变化由 client HMR 自动推送，`Cmd+R` 刷新页面即可。

**宠物不动了？** 双击过会冻结散步（记忆在 localStorage），再双击恢复。

## 卸载

```bash
bash uninstall.sh   # 移除软链 + profile patch 行
# 然后 Cmd+Q 重启 DSH Desktop
```

## 仓库结构

```
dsh-plugin-pet/
├── pet-plugin/               # 插件包（DSH 双半插件格式）
│   ├── package.json          # dsh.client 声明 + exports
│   └── lib/
│       ├── index.js          # host 半（纯 UI 插件，空 apply）
│       └── client.js.tpl     # 浏览器半模板（真正源码，含全部行为）
├── tools/
│   ├── measure_sheet.js      # 精灵网格测量：PNG 解码 + alpha 空白带扫描 + 契约检测
│   └── build_client.js       # 共享构建器：解析素材→测量→渲染模板→双重验证门
├── install.sh                # 安装（构建 + 软链 + 双 profile YAML 安全补丁）
├── uninstall.sh              # 卸载
├── switch_pet.sh             # 一键换宠/重建
└── README.md / CHANGELOG.md / LICENSE
```

## 许可

[MIT](LICENSE)。精灵素材归各自所有者——本仓库不分发任何宠物图像。
