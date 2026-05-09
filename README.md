# seedance-video

火山引擎方舟 Seedance 视频生成 skill 源目录，支持文生视频和图生视频。

## 当前结构

| 路径 | 用途 |
|------|------|
| `SKILL.md` | Codex / OpenAI 风格 skill 入口，包含触发描述和工作流 |
| `agents/openai.yaml` | skill 列表中的展示文案和默认提示 |
| `scripts/seedance_video.py` | 稳定的命令行入口，负责提交任务、轮询结果、下载视频 |
| `references/openapi.yaml` | 原始 API 参考，按需读取 |

## 使用方式

这个目录现在已经是一个标准 skill 包雏形。

- 给 Codex 用：把整个目录安装到 `~/.codex/skills/volcengine-generate-video/`
- 给其他支持 skill 目录的平台用：优先使用 `SKILL.md`
- 给需要工具桥接的平台用：使用 `references/openapi.yaml` 再接 MCP / plugin / 自定义 server

## 环境变量

| 变量 | 说明 |
|------|------|
| `ARK_API_KEY` | 火山引擎方舟 API Key，前往 [控制台](https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey) 获取 |

## 命令示例

```bash
python3 scripts/seedance_video.py \
  --prompt "A cinematic food commercial shot of noodles steaming on a wooden table"
```
