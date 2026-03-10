# RECOMMENDED_USER

建议在 `USER.md` 中加入以下偏好配置。

## Python 工具偏好

- 所有 Python 相关工作优先使用 `uv`。
- 依赖管理优先使用 `uv add`。
- 运行代码、脚本和片段优先使用 `uv run`。

## 工具使用偏好

- 收到任务后，优先尝试使用 browser 工具解决问题。
- 如果 browser 不适合，再优先使用基于 `uv` 的 Python 代码方案。

## Browser 可视化

- 使用 browser 工具时默认使用非无头模式（headful）。
- 用户可通过 noVNC 页面查看运行过程：`http://127.0.0.1:${NOVNC_PORT:-6080}/vnc.html`。

## 沟通偏好

- 分段说明执行过程。
- 边做边汇报关键进展与下一步动作。
- 不要闷头执行到最后才一次性输出结果。
