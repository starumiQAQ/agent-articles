# Agent Instructions

这是一个收集高质量 AI Agent（智能体）构建相关文章、论文和最佳实践的仓库。本文档告诉 AI 助手如何正确地与这个仓库交互。

## 仓库结构

```
agent-articles/
├── AGENTS.md              ← 本文件：给 AI 助手的说明
├── README.md              ← 仓库首页，需要保持与文件系统同步
├── anthropic/             ← Anthropic 文章
│   └── building-effective-agents.md
├── openai/                ← OpenAI 文章
│   ├── a-practical-guide-to-building-agents.md
│   └── function-calling.md
└── ...                    ← 未来新增来源方目录
```

## 目录命名规则

- 文章按**来源方**分目录，目录名使用小写英文
- 示例：`anthropic/`、`openai/`、`google/`、`microsoft/`、`deepmind/`

## 文件命名规则

- 文件名使用文章的 URL slug 或简短的英文描述
- 使用连字符 `-` 分隔单词
- 扩展名为 `.md`
- 示例：`building-effective-agents.md`、`a-practical-guide-to-building-agents.md`

## 文章格式规范

每篇文章必须包含以下 YAML 风格的元信息头部：

```markdown
# 原文标题（中文翻译标题）

> **原文**: [文章标题](原文URL)
> **作者**: 作者名/机构名
> **发布时间**: YYYY-MM-DD
> **翻译**: 中文翻译
```

### 正文要求

- 保留原文的标题层级结构（H1、H2、H3 等）
- 中文正文中使用中文标点符号
- 关键术语首次出现时保留英文原文在括号中：`工作流（workflow）`
- 代码示例保留原文语言，不做翻译
- 可以添加 ASCII 图表帮助理解工作流模式
- 列表、引用等格式转换为中文排版规范

## 添加新文章的工作流

当用户要求添加新文章时，AI 助手应按以下步骤操作：

1. **获取原文**：通过 fetch_url 或浏览器工具获取文章内容
2. **拉取最新代码**：`git pull origin master`
3. **创建目录和文件**：按来源方新建目录 `.md` 文件
4. **翻译并格式化**：按上述格式规范完成翻译
5. **更新 README**：在文章列表表格和目录部分添加新条目
6. **提交并推送**：
   - `git add -A`
   - `git commit -m "add [source] [article title] translation"`
   - `git push`

## 翻译原则

- **准确性优先**：技术术语应准确翻译，关键术语保留英文原文
- **可读性**：中文表达自然流畅，避免生硬的直译
- **一致性**：同一术语在全文中保持统一的翻译
- **完整保留**：不删减原文内容，附录和脚注一并翻译
- **代码不译**：所有代码示例保持原样

## 常用术语翻译对照

| English | 中文 |
|---------|------|
| agent | 智能体 |
| agentic system | 智能体系统 |
| workflow | 工作流 |
| prompt chaining | 提示链 |
| routing | 路由 |
| parallelization | 并行化 |
| orchestrator-workers | 编排器-工作者 |
| evaluator-optimizer | 评估器-优化器 |
| guardrails | 护栏 |
| handoff | 交接 |
| tool | 工具 |
| LLM | 大语言模型 |
| guardrail | 护栏 |
| augmented LLM | 增强型 LLM |
| model | 模型 |
| multi-agent | 多智能体 |
| agent loop | 智能体循环 |
