# seedance-video

火山引擎方舟 Seedance 视频生成 skill 源目录，支持文生视频和图生视频。

## 当前结构

| 路径 | 用途 |
|------|------|
| `SKILL.md` | Codex / OpenAI 风格 skill 入口，包含触发描述和工作流 |
| `agents/openai.yaml` | skill 列表中的展示文案和默认提示 |
| `scripts/seedance_video.sh` | 稳定的命令行入口，负责提交任务、轮询结果、下载视频 |
| `references/openapi.yaml` | 原始 API 参考，按需读取 |

## 如何使用

将以下提示词复制给你的 AI 智能体（Claude Code、Codex、Cursor、Windsurf、GitHub Copilot、OpenClaw（小龙虾）、Trae 等），它会自动完成安装：

> 请帮我安装生成视频 Skill。
>
> 仓库文档：https://github.com/kaoputou/volcengine-generate-video-skill

## API Key

默认不需要手动设置环境变量。

- 首次运行脚本时，会提示输入一次火山方舟 API Key
- 输入后会自动保存到本地配置文件
- 后续再次运行时会自动读取，不需要再 `export ARK_API_KEY=...`
- 默认保存位置是 `~/.volcengine-generate-video/ark_api_key`
- API Key 可在 [控制台](https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey) 获取

## 命令示例

```bash
bash scripts/seedance_video.sh \
  --prompt "A cinematic food commercial shot of noodles steaming on a wooden table"
```

如果你想提前保存 API Key，也可以先运行：

```bash
bash scripts/seedance_video.sh --set-api-key
```
