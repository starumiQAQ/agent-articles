# Function Calling（函数调用）

> **原文**: [Function calling](https://developers.openai.com/api/docs/guides/function-calling)
> **作者**: OpenAI
> **发布时间**: 2026
> **翻译**: 中文翻译

---

**函数调用**（function calling，也称**工具调用**）为 OpenAI 模型提供了一种强大而灵活的方式来与外部系统交互，并访问其训练数据之外的信息。本指南展示了如何将模型连接到应用程序提供的数据和操作。我们将介绍如何使用函数工具（通过 JSON 模式定义）以及支持自由格式文本输入输出的自定义工具。

如果您的应用程序有大量函数或大型模式，可以将函数调用与[工具搜索](https://developers.openai.com/api/docs/guides/tools-tool-search)搭配使用，以延迟加载不常用的工具，仅在模型需要时才加载。只有 `gpt-5.4` 及更高版本的模型支持 `tool_search`。

---

## 工作原理（How it works）

让我们从理解几个关键术语开始。在建立关于工具调用的共享词汇后，我们将通过实际示例展示具体实现。

### 工具（Tools）——赋予模型的功能

**函数**或**工具**抽象地指代我们告知模型可访问的功能。当模型生成对提示的响应时，它可能决定需要某个工具提供的数据或功能来遵循提示中的指令。

你可以赋予模型访问以下工具的权限：

- 获取某个位置的今日天气
- 查询指定用户 ID 的账户详情
- 为丢失的订单发起退款

或者其他任何你希望模型在响应提示时能够了解或执行的功能。

当我们向模型发出带有提示的 API 请求时，可以包含一个模型可能考虑使用的工具列表。例如，如果我们希望模型能够回答关于全球某地当前天气的问题，可以赋予它一个接受 `location` 参数的 `get_weather` 工具。

### 工具调用（Tool calls）——模型使用工具的请求

**函数调用**或**工具调用**指一种特殊的响应类型：模型分析提示后，确定为了遵循提示中的指令，需要调用我们提供的工具之一。

如果模型收到类似「巴黎的天气如何？」的提示，它可以返回一个针对 `get_weather` 工具的工具调用，其中 `location` 参数值为 `Paris`。

### 工具调用输出（Tool call outputs）——为模型生成的输出

**函数调用输出**或**工具调用输出**指工具根据模型工具调用的输入生成的响应。工具调用输出可以是结构化 JSON 或纯文本，并且应包含对特定模型工具调用的引用（在后续示例中通过 `call_id` 引用）。

继续我们的天气示例：

- 模型可以访问一个接受 `location` 参数的 `get_weather` **工具**。
- 对于「巴黎的天气如何？」这样的提示，模型返回一个包含 `location` 参数（值为 `Paris`）的**工具调用**。
- **工具调用输出**可能返回一个 JSON 对象（例如 `{"temperature": "25", "unit": "C"}`，表示当前温度 25 度）、[图片内容](https://developers.openai.com/api/docs/guides/images)或[文件内容](https://developers.openai.com/api/docs/guides/file-inputs)。

然后，我们将工具定义、原始提示、模型的工具调用以及工具调用输出一起发送回模型，最终接收文本响应：

```
The weather in Paris today is 25C.
```

### 函数与工具的区别（Functions versus tools）

- **函数**是一种特定类型的工具，由 JSON 模式定义。函数定义允许模型将数据传递给应用程序，应用程序代码可以访问模型建议的数据或执行模型建议的操作。
- 除函数工具外，还有**自定义工具（custom tools）**（本指南中将介绍），它们支持自由格式的文本输入输出。
- 还有作为 OpenAI 平台一部分的**[内置工具（built-in tools）](https://developers.openai.com/api/docs/guides/tools)**。这些工具使模型能够[搜索网络](https://developers.openai.com/api/docs/guides/tools-web-search)、[执行代码](https://developers.openai.com/api/docs/guides/tools-code-interpreter)、访问 [MCP 服务器](https://developers.openai.com/api/docs/guides/tools-remote-mcp)的功能等。

### 工具调用流程（The tool calling flow）

工具调用是应用程序与模型之间通过 OpenAI API 进行的多步骤对话。工具调用流程包含五个高层步骤：

1. 向模型发起请求，附带其可以调用的工具
2. 接收来自模型的工具调用
3. 在应用程序端使用工具调用的输入执行代码
4. 向模型发起第二次请求，附带工具输出
5. 接收模型的最终响应（或更多工具调用）

![Function Calling Diagram Steps](https://cdn.openai.com/API/docs/images/function-calling-diagram-steps.png)

---

## 函数工具示例（Function tool example）

让我们来看一个端到端的工具调用流程示例，使用 `get_horoscope` 函数获取某个星座的每日运势。

注意，对于推理模型（如 GPT-5 或 o4-mini），模型响应中返回的包含工具调用的任何推理条目，在传回工具调用输出时也必须一并传回。

## 定义函数（Defining functions）

函数通常在每个 API 请求的 `tools` 参数中声明。使用[工具搜索](https://developers.openai.com/api/docs/guides/tools-tool-search)时，应用程序还可以在后续交互中加载延迟函数。无论哪种方式，每个可调用函数都使用相同的模式结构。函数定义包含以下属性：

| 字段 | 描述 |
|------|------|
| `type` | 应始终为 `function` |
| `name` | 函数名称（例如 `get_weather`） |
| `description` | 关于何时以及如何使用函数的详细信息 |
| `parameters` | 定义函数输入参数的 [JSON 模式](https://json-schema.org/) |
| `strict` | 是否对函数调用启用严格模式 |

以下是一个 `get_weather` 函数的定义示例：

```json
{
  "type": "function",
  "name": "get_weather",
  "description": "Retrieves current weather for the given location.",
  "parameters": {
    "type": "object",
    "properties": {
      "location": {
        "type": "string",
        "description": "City and country e.g. Bogotá, Colombia"
      },
      "units": {
        "type": "string",
        "enum": ["celsius", "fahrenheit"],
        "description": "Units the temperature will be returned in."
      }
    },
    "required": ["location", "units"],
    "additionalProperties": false
  },
  "strict": true
}
```

由于 `parameters` 由 [JSON 模式](https://json-schema.org/)定义，你可以利用其丰富的特性，如属性类型、枚举、描述、嵌套对象和递归对象。

## 定义命名空间（Defining namespaces）

使用命名空间按领域（如 `crm`、`billing` 或 `shipping`）对相关工具进行分组。命名空间有助于组织相似的工具，尤其在模型必须在服务于不同系统或目的的工具之间做出选择时非常有用，例如一个用于 CRM 的搜索工具和另一个用于支持工单系统的搜索工具。

```json
{
  "type": "namespace",
  "name": "crm",
  "description": "CRM tools for customer lookup and order management.",
  "tools": [
    {
      "type": "function",
      "name": "get_customer_profile",
      "description": "Fetch a customer profile by customer ID.",
      "parameters": {
        "type": "object",
        "properties": {
          "customer_id": { "type": "string" }
        },
        "required": ["customer_id"],
        "additionalProperties": false
      }
    },
    {
      "type": "function",
      "name": "list_open_orders",
      "description": "List open orders for a customer ID.",
      "defer_loading": true,
      "parameters": {
        "type": "object",
        "properties": {
          "customer_id": { "type": "string" }
        },
        "required": ["customer_id"],
        "additionalProperties": false
      }
    }
  ]
}
```

## 工具搜索（Tool search）

如果你需要让模型访问大量工具生态系统，可以使用 `tool_search` 延迟加载部分或全部工具。`tool_search` 工具允许模型搜索相关工具、将其添加到模型上下文中，然后使用它们。只有 `gpt-5.4` 及更高版本的模型支持。请阅读[工具搜索指南](https://developers.openai.com/api/docs/guides/tools-tool-search)了解更多。

### 定义函数的最佳实践（Best practices for defining functions）

1. **编写清晰详细的函数名称、参数描述和说明。**
   - **明确描述函数的目的和每个参数**（及其格式），以及输出代表什么。
   - **使用系统提示描述何时（以及何时不）使用每个函数。** 通常，准确地告诉模型该做什么。
   - **包含示例和边缘情况**，特别是在修复反复出现的失败时。（**注意：** 为[推理模型](https://developers.openai.com/api/docs/guides/reasoning)添加示例可能会降低性能。）
   - **对于延迟加载的工具，将详细指导放在函数描述中，保持命名空间描述简洁。** 命名空间帮助模型选择加载什么；函数描述帮助模型正确使用已加载的工具。

2. **应用软件工程最佳实践。**
   - **使函数直观明了**（[最少意外原则](https://en.wikipedia.org/wiki/Principle_of_least_astonishment)）。
   - **使用枚举**和对象结构使无效状态不可表示（例如 `toggle_light(on: bool, off: bool)` 允许无效调用）。
   - **通过实习生测试。** 一个实习生/人类仅凭你提供给模型的信息能否正确使用该函数？如果不能，他们会问你什么问题？将答案添加到提示中。

3. **将负担从模型转移到代码上。**
   - **不要让模型填写你已经知道的参数。** 例如，如果你已经基于之前的菜单有了 `order_id`，就不要设置 `order_id` 参数——使用无参数的 `submit_refund()` 并通过代码传递 `order_id`。
   - **合并总是按顺序调用的函数。** 例如，如果你总是在 `query_location()` 之后调用 `mark_location()`，直接将标记逻辑移到查询函数调用中。

4. **保持初始可用函数数量较少以提高准确性。**
   - 评估不同函数数量下的**性能**。
   - 建议在单次轮次开始时保持**少于 20 个函数**可用，但这仅为软性建议。
   - **使用工具搜索**来延迟加载工具表面中较大或不常用的部分，而不是一开始就暴露所有内容。

5. **充分利用 OpenAI 资源。**
   - 在 [Playground](https://platform.openai.com/playground) 中**生成和迭代函数模式**。
   - 考虑使用**[微调](https://developers.openai.com/api/docs/guides/fine-tuning)来提高函数调用准确性**，尤其适用于大量函数或困难任务。（[cookbook](https://developers.openai.com/cookbook/examples/fine_tuning_for_function_calling)）

### 令牌用量（Token Usage）

在底层，函数以模型训练过的语法注入到系统消息中。这意味着可调用的函数定义会计入模型的上下文限制，并作为输入令牌计费。如果遇到令牌限制，建议限制初始加载的函数数量、尽量缩短描述，或使用[工具搜索](https://developers.openai.com/api/docs/guides/tools-tool-search)以便仅在需要时加载延迟工具。

如果在工具规范中定义了大量函数，也可以使用[微调](https://developers.openai.com/api/docs/guides/fine-tuning#fine-tuning-examples)来减少使用的令牌数量。

---

## 处理函数调用（Handling function calls）

当模型调用函数时，你必须执行该函数并返回结果。由于模型响应可能包含零个、一个或多个调用，最佳实践是假设有多个调用。

响应的 `output` 数组包含 `type` 值为 `function_call` 的条目。每个条目包含 `call_id`（用于后续提交函数结果）、`name` 和 JSON 编码的 `arguments`。

如果你正在使用[工具搜索](https://developers.openai.com/api/docs/guides/tools-tool-search)，在 `function_call` 之前还可能看到 `tool_search_call` 和 `tool_search_output` 条目。函数加载后，处理函数调用的方式与这里展示的相同。

### 格式化结果（Formatting results）

在 `function_call_output` 消息中传入的结果通常应为字符串，格式由你决定（JSON、错误代码、纯文本等）。模型会根据需要解释该字符串。

对于返回图片或文件的函数，可以传入[图片或文件对象数组](https://developers.openai.com/api/docs/api-reference/responses/create#responses_create-input-input_item_list-item-function_tool_call_output-output)代替字符串。

如果你的函数没有返回值（例如 `send_email`），只需返回一个表示成功或失败的字符串（例如 `"success"`）。

### 将结果纳入响应（Incorporating results into response）

将结果追加到 `input` 后，可以将其发送回模型以获取最终响应。

---

## 额外配置（Additional configurations）

### 工具选择（Tool choice）

默认情况下，模型将决定何时以及使用多少个工具。你可以使用 `tool_choice` 参数强制指定行为。

1. **Auto（自动）：**（默认）调用零个、一个或多个函数。`tool_choice: "auto"`
2. **Required（强制）：** 调用一个或多个函数。`tool_choice: "required"`
3. **Forced Function（强制函数）：** 精确调用一个特定函数。`tool_choice: {"type": "function", "name": "get_weather"}`
4. **Allowed Tools（允许的工具）：** 将模型可以进行的工具调用限制为模型可用工具的子集。

**何时使用 allowed_tools**

如果你希望在跨模型请求时仅暴露一部分工具可用，但又不修改传入的工具列表（以便最大化[提示缓存](https://developers.openai.com/api/docs/guides/prompt-caching)节省），可以配置 `allowed_tools` 列表。

```json
"tool_choice": {
    "type": "allowed_tools",
    "mode": "auto",
    "tools": [
        { "type": "function", "name": "get_weather" },
        { "type": "function", "name": "search_docs" }
    ]
  }
}
```

你也可以将 `tool_choice` 设置为 `"none"` 来模拟不传递任何函数的行为。

当你使用工具搜索时，`tool_choice` 仍然适用于当前轮次中可调用的工具。这在加载工具子集后希望将模型约束到该子集时最为有用。

### 并行函数调用（Parallel function calling）

使用[内置工具](https://developers.openai.com/api/docs/guides/tools)时无法进行并行函数调用。

模型可能选择在单次轮次中调用多个函数。你可以通过设置 `parallel_tool_calls` 为 `false` 来阻止此行为，确保恰好调用零个或一个工具。

**注意：** 如果你使用微调模型且模型在一次轮次中调用了多个函数，则这些调用的[严格模式](#严格模式)将被禁用。

**注意（针对 `gpt-4.1-nano-2025-04-14`）：** 此快照版本的 `gpt-4.1-nano` 在启用并行工具调用时，有时会对同一工具包含多次工具调用。建议在使用此 nano 快照时禁用此功能。

### 严格模式（Strict mode）

将 `strict` 设置为 `true` 将确保函数调用可靠地遵循函数模式，而非尽力而为。我们建议始终启用严格模式。

在底层，严格模式通过利用[结构化输出](https://developers.openai.com/api/docs/guides/structured-outputs)功能来工作，因此引入了以下要求：

1. `parameters` 中每个对象的 `additionalProperties` 必须设置为 `false`。
2. `properties` 中的所有字段必须标记为 `required`。

你可以通过添加 `null` 作为 `type` 选项来表示可选字段（见下方示例）。

如果你发送 `strict: true` 而模式不满足上述要求，请求将被拒绝，并附带缺失约束的详细信息。如果你省略 `strict`，默认行为取决于 API：Responses 请求会将模式规范化为严格模式（例如，通过设置 `additionalProperties: false` 并将所有字段标记为 required），这可能会使以前可选的字段变为必填；而 Chat Completions 请求默认保持非严格模式。要在 Responses API 中选择退出严格模式并保持非严格的尽力而为函数调用，请明确设置 `strict: false`。

在 [Playground](https://platform.openai.com/playground) 中生成的所有模式都启用了严格模式。

虽然我们建议启用严格模式，但它有一些限制：

1. JSON 模式的某些功能不受支持。（参见[支持的模式](https://developers.openai.com/api/docs/guides/structured-outputs?context=with_parse#supported-schemas)。）

针对微调模型：

1. 模式在首次请求时会经过额外处理（然后被缓存）。如果你的模式在不同请求之间变化，这可能会导致更高的延迟。
2. 模式因性能原因被缓存，不符合[零数据保留](https://developers.openai.com/api/docs/models#how-we-use-your-data)的条件。

---

## 流式处理（Streaming）

流式处理可用于通过显示模型填充参数时正在调用哪个函数来展示进度，甚至可以实时显示参数。

流式函数调用与流式传输常规响应非常相似：设置 `stream` 为 `true`，然后接收不同的 `event` 对象。

不同的是，你不是将片段聚合为单个 `content` 字符串，而是将片段聚合为编码后的 `arguments` JSON 对象。

当模型调用一个或多个函数时，将发出 `response.output_item.added` 类型的事件，每个函数调用对应一个，包含以下字段：

| 字段 | 描述 |
|------|------|
| `response_id` | 函数调用所属响应的 ID |
| `output_index` | 响应中输出项的索引。表示响应中的各个函数调用。 |
| `item` | 正在进行的函数调用项，包含 `name`、`arguments` 和 `id` 字段 |

之后，你将接收到一系列 `response.function_call_arguments.delta` 类型的事件，其中包含 `arguments` 字段的 `delta`。这些事件包含以下字段：

| 字段 | 描述 |
|------|------|
| `response_id` | 函数调用所属响应的 ID |
| `item_id` | delta 所属的函数调用项的 ID |
| `output_index` | 响应中输出项的索引。表示响应中的各个函数调用。 |
| `delta` | `arguments` 字段的增量。 |

以下代码片段演示了如何将 `delta` 聚合为最终的 `tool_call` 对象。

当模型完成函数调用后，将发出 `response.function_call_arguments.done` 类型的事件。此事件包含完整的函数调用，包括以下字段：

| 字段 | 描述 |
|------|------|
| `response_id` | 函数调用所属响应的 ID |
| `output_index` | 响应中输出项的索引。表示响应中的各个函数调用。 |
| `item` | 函数调用项，包含 `name`、`arguments` 和 `id` 字段。 |

---

## 自定义工具（Custom tools）

自定义工具的工作方式与 JSON 模式驱动的函数工具大致相同。区别在于，自定义工具不需要向模型提供关于工具输入要求的明确指令，模型可以将任意字符串作为输入传递给工具。这对于避免不必要地将响应包装在 JSON 中，或对响应应用自定义语法（下文详述）非常有用。

以下代码示例展示了创建一个自定义工具，该工具期望接收一段包含 Python 代码的文本字符串作为响应。

与之前一样，`output` 数组将包含模型生成的工具调用。不同的是，这次工具调用的输入是纯文本形式给出的。

```json
[
  {
    "id": "rs_6890e972fa7c819ca8bc561526b989170694874912ae0ea6",
    "type": "reasoning",
    "content": [],
    "summary": []
  },
  {
    "id": "ctc_6890e975e86c819c9338825b3e1994810694874912ae0ea6",
    "type": "custom_tool_call",
    "status": "completed",
    "call_id": "call_aGiFQkRWSWAIsMQ19fKqxUgb",
    "input": "print(\"hello world\")",
    "name": "code_exec"
  }
]
```

### 上下文无关语法（Context-free grammars）

[上下文无关文法](https://en.wikipedia.org/wiki/Context-free_grammar)（CFG）是一组规则，定义如何在给定格式中生成有效文本。对于自定义工具，你可以提供一个 CFG 来约束模型对自定义工具的文本输入。

你可以通过配置自定义工具时的 `grammar` 参数提供自定义 CFG。目前，我们支持两种 CFG 语法：`lark` 和 `regex`。

#### Lark CFG

工具的输出应符合你定义的 Lark CFG：

```json
[
  {
    "id": "rs_6890ed2b6374819dbbff5353e6664ef103f4db9848be4829",
    "type": "reasoning",
    "content": [],
    "summary": []
  },
  {
    "id": "ctc_6890ed2f32e8819daa62bef772b8c15503f4db9848be4829",
    "type": "custom_tool_call",
    "status": "completed",
    "call_id": "call_pmlLjmvG33KJdyVdC4MVdk5N",
    "input": "4 + 4",
    "name": "math_exp"
  }
]
```

语法使用 [Lark](https://lark-parser.readthedocs.io/en/stable/index.html) 的变体指定。模型采样使用 [LLGuidance](https://github.com/guidance-ai/llguidance/blob/main/docs/syntax.md) 进行约束。Lark 的某些功能不受支持：

- 词法分析器正则表达式中的环视（Lookarounds）
- 词法分析器正则表达式中的惰性修饰符（`*?`、`+?`、`??`）
- 终结符优先级
- 模板
- 导入（内置 `%import common` 除外）
- `%declare` 声明

我们建议使用 [Lark IDE](https://www.lark-parser.org/ide/) 来尝试自定义语法。

#### 保持语法简洁（Keep grammars simple）

尽量使你的语法尽可能简单。OpenAI API 可能在语法过于复杂时返回错误，因此在 API 中使用前应确保所需语法兼容。

Lark 语法可能难以完美掌握。简单的语法最为可靠，而复杂的语法通常需要在语法定义本身、提示和工具描述上进行反复迭代，以确保模型不会超出分布范围。

#### 正确与错误模式（Correct versus incorrect patterns）

**正确**（单个、有边界的终结符）：

```
start: SENTENCE
SENTENCE: /[A-Za-z, ]*(the hero|a dragon|an old man|the princess)[A-Za-z, ]*(fought|saved|found|lost)[A-Za-z, ]*(a treasure|the kingdom|a secret|his way)[A-Za-z, ]*\./
```

**不要这样做**（跨规则/终结符拆分）。这试图让规则在终结符之间划分自由文本。词法分析器会贪婪地匹配自由文本片段，你将失去控制：

```
start: sentence
sentence: /[A-Za-z, ]+/ subject /[A-Za-z, ]+/ verb /[A-Za-z, ]+/ object /[A-Za-z, ]+/
```

小写规则不影响终结符如何从输入中切分——只有终结符定义决定。当你需要在「锚点之间」有自由文本时，将其设为一个大的正则表达式终结符，以便词法分析器恰好匹配一次并保持你期望的结构。

#### 终结符与规则（Terminals versus rules）

Lark 使用终结符（terminals）作为词法分析器令牌（约定使用 `大写`），使用规则（rules）作为解析器产生式（约定使用 `小写`）。保持在支持子集内并避免意外的最实用方法是保持语法简单明确，并清晰区分终结符和规则。

终结符使用的正则表达式语法是 [Rust regex crate 语法](https://docs.rs/regex/latest/regex/#syntax)，而非 Python 的 `re` [模块](https://docs.python.org/3/library/re.html)。

#### 关键概念和最佳实践（Key ideas and best practices）

**词法分析器在解析器之前运行**

终结符由词法分析器匹配（贪婪/最长匹配优先），然后才应用任何 CFG 规则逻辑。如果你试图通过将终结符拆分为多个规则来「塑造」它，词法分析器无法受到这些规则的指导——只能受终结符正则表达式指导。

**当你从自由格式文本中提取内容时，优先使用一个终结符**

如果你需要识别嵌入在任意文本中的模式（例如带有锚点间「任意内容」的自然语言），将其表达为单个终结符。不要试图将自由文本终结符与解析器规则交错使用；贪婪的词法分析器不会尊重你预期的边界，模型很可能会超出分布范围。

**使用规则组合离散令牌**

当组合清晰分隔的终结符（数字、关键字、标点符号）为更大的结构时，规则是理想选择。它们不适合约束两个终结符之间的「中间内容」。

**保持终结符简单、有边界、自包含**

优先使用明确的字符类和有限量词（`{0,10}`，而不是到处使用无界的 `*`）。如果你需要「直到句点的任意文本」，使用 `/[^.\n]{0,10}*\./` 而非 `/.+\./` 以避免失控增长。

**使用规则组合令牌，而非引导正则表达式内部**

良好规则使用示例：

```
start: expr
NUMBER: /[0-9]+/
PLUS: "+"
MINUS: "-"
expr: term (("+"|"-") term)*
term: NUMBER
```

**明确处理空白**

不要依赖无边界的 `%ignore` 指令。使用无界忽略指令可能导致语法过于复杂和/或导致模型超出分布范围。优先在允许空白的地方显式使用终结符。

#### 故障排除（Troubleshooting）

- 如果 API 因语法过于复杂而拒绝，请简化规则和终结符，移除无界的 `%ignore` 指令。
- 如果自定义工具被调用时出现意外令牌，请确认终结符没有重叠；检查贪婪词法分析器。
- 当模型漂移出分布范围（表现为模型生成过长或重复的输出，语法有效但语义错误）：
  - 收紧语法。
  - 迭代提示（添加少样本示例）和工具描述（解释语法并指导模型推理和遵循）。
  - 尝试更高的推理努力级别（例如从中等提升到高等）。

#### Regex CFG

工具的输出应符合你定义的 Regex CFG：

```json
[
  {
    "id": "rs_6894f7a3dd4c81a1823a723a00bfa8710d7962f622d1c260",
    "type": "reasoning",
    "content": [],
    "summary": []
  },
  {
    "id": "ctc_6894f7ad7fb881a1bffa1f377393b1a40d7962f622d1c260",
    "type": "custom_tool_call",
    "status": "completed",
    "call_id": "call_8m4XCnYvEmFlzHgDHbaOCFlK",
    "input": "August 7th 2025 at 10AM",
    "name": "timestamp"
  }
]
```

与 Lark 语法一样，正则表达式使用 [Rust regex crate 语法](https://docs.rs/regex/latest/regex/#syntax)，而非 Python 的 `re` [模块](https://docs.python.org/3/library/re.html)。

Regex 的某些功能不受支持：

- 环视（Lookarounds）
- 惰性修饰符（`*?`、`+?`、`??`）

#### 关键概念和最佳实践（Key ideas and best practices）

**模式必须在单行内**

如果需要匹配输入中的换行符，使用转义序列 `\n`。不要使用详细/扩展模式，该模式允许跨多行的模式。

**以纯模式字符串形式提供正则表达式**

不要将模式包裹在 `//` 中。
