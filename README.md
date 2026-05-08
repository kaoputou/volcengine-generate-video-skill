# seedance-video

火山引擎方舟 Seedance 视频生成工具，支持文生视频和图生视频。

## 如何使用

将以下提示词复制给你的 AI 智能体（Claude Code、Codex、Cursor、Windsurf、GitHub Copilot、OpenClaw（小龙虾）、Trae 等），它会自动完成安装：

> 请帮我安装生成视频 Skill。
>
> 仓库文档：https://github.com/kaoputou/volcengine-generate-video-skill

## 文件说明

| 文件 | 用途 |
|------|------|
| `skill.md` | Claude Code Skill，直接在 Claude Code 中使用 |
| `openapi.yaml` | OpenAPI 3.1 接口定义，配合 MCP 桥接工具暴露给其他智能体 |


## 环境变量

| 变量 | 说明 |
|------|------|
| `ARK_API_KEY` | 火山引擎方舟 API Key，前往 [控制台](https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey) 获取 |
