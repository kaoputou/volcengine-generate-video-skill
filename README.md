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

## 环境变量

| 变量 | 说明 |
|------|------|
| `ARK_API_KEY` | 火山引擎方舟 API Key，前往 [控制台](https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey) 获取 |

## 命令示例

```bash
bash scripts/seedance_video.sh \
  --prompt "A cinematic food commercial shot of noodles steaming on a wooden table"
```
