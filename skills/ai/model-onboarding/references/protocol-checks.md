# 三协议验收清单

执行 Chat / Messages / Responses 接入测试时阅读本文件。先确认请求打到待测模型和渠道，再比较协议语义；相同 HTTP 状态码不代表相同能力。

## 记录格式

每个模型、渠道、版本分别填写一组，记录测试时间、发起主机、SDK/客户端版本和脱敏请求 ID。上游与网关应分别保存结果。

| 协议 | 上游原生 | 网关实现方式 | 文本非流式 | 文本流式 | 工具非流式完整回合 | 工具流式完整回合 | 限制与证据 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Chat Completions | 待测 | 原生/转换/无路由 | 待测 | 待测 | 待测 | 待测 | 请求 ID、记录路径 |
| Anthropic Messages | 待测 | 原生/转换/无路由 | 待测 | 待测 | 待测 | 待测 | 请求 ID、记录路径 |
| Responses | 待测 | 原生/转换/无路由 | 待测 | 待测 | 待测 | 待测 | 请求 ID、记录路径 |

请求中包含模型 ID、必要鉴权、最小输入与有限输出预算。工具测试使用无副作用的本地假工具；不要执行模型生成的任意命令。

## 工具调用验收

每个变更模型和渠道都要评估工具能力。声明支持工具的协议必须分别通过非流式与流式完整回合；不支持的模式注明限制。原生协议通过不能代替网关转换后的验收；命中备用渠道也不能算待测渠道通过。

使用一个可判定结果的假工具，例如 `lookup_test_value`：输入 schema 要求字符串 `key`，枚举只允许 `case-1`。提示模型必须调用该工具取得值并在最终回答中原样返回。测试程序在执行假工具时生成随机标记，通过 `{"value":"<本次随机标记>"}` 返回；标记不得提前放入提示词或工具定义。

1. **生成调用：**使用实际客户端的工具声明与调用模式，核对结构化调用中的名称、调用 ID 和参数。参数应满足 schema，且 `key` 为 `case-1`；模型在普通文本中描述调用、编造结果或跳过工具均不算通过。
2. **回传结果：**保留协议要求的助手历史、推理块或签名，使用匹配的调用 ID 回传假工具结果。Chat 使用 `tool_call_id`，Messages 使用 `tool_result.tool_use_id`，Responses 使用 `function_call_output.call_id`；不要把 Responses item ID 当作 call ID。
3. **继续回答：**第二次请求必须得到包含该随机标记的最终回答，并正常结束；不能止于收到第一轮工具调用、再次循环调用工具、空响应、截断或流内错误。
4. **流式重测：**两次请求均启用流式，检查调用 ID、工具名、参数分片的关联，按序组装完成后再解析 JSON、校验 schema 并执行假工具。确认客户端只执行一次调用，第二轮回答与终止事件也能正确消费。

生产使用自动工具选择时，至少用该模式完成上述验收；仅强制指定工具成功不足以证明实际客户端可用。只有声明或实际使用强制选择、并行工具、工具错误回传等功能时才加测对应场景；不支持的高级选项与基础工具回合分开记录。

证据应包含两次请求的关联、实际渠道、协议调用 ID、参数校验结果、回传标记与最终回答、结束状态；流式记录关键事件与组装结果即可。HTTP 200、`tools` 参数未报错、能力元数据为 true，都不能替代这些证据。

## Chat Completions

- 非流式：验证 `messages` 多轮输入，`choices[].message`、`finish_reason` 和 usage 的可解析性；工具回复或长度截断不能当作普通文本结束。
- 流式：验证 SSE 增量、`choices[].delta`、索引和终止语义，确认客户端不会等待到断链才显示文字。支持 usage chunk 时检查其位置及空 choices 的处理。
- 工具：检查 `tool_calls` 的 ID、函数名与分片参数；组装后参数必须是有效 JSON，工具结果按相同 `tool_call_id` 回传后能继续回答。
- 参数：核实该模型使用 `max_tokens` 还是 `max_completion_tokens`，以及 system/developer 角色、推理控制等具体支持范围。

## Anthropic Messages

- 非流式：按该服务要求配置 API key 和版本头，验证顶层 `system`、`messages`、`max_tokens`；响应应包含可解析的 content blocks、`stop_reason` 与 usage。
- 流式：检查 `message_start`、content block 的开始/增量/结束、`message_delta`、`message_stop` 的一致性及索引；心跳不能计作首字。
- 工具：验证 `tool_use` 的 ID、名称和 input，流式工具参数能够完整组装；匹配的 `tool_result` 回传后，模型可继续回答。
- 推理：对声明支持的 thinking block、signature 或交错推理做保留和回传检查；不支持的字段应明确限制，不能静默丢弃后宣称完整兼容。

## Responses

- 非流式：验证 `input` / `instructions` 与项目需要的多轮输入形式；解析 response 的 `output` items、`status` 和 usage，不按 Chat 的 `choices` 读取。
- 流式：验证输出 item/content/delta 的关联及终止状态；区分完成、不完整和失败。仅把 Chat SSE 改名或套壳，不能证明 Responses 兼容。
- 工具：确认 `function_call` 的 `call_id` 与参数，回传匹配的 `function_call_output` 后能继续生成；区分 item ID 与工具调用 ID。
- 状态：基础文本通过后，只有实际使用 `previous_response_id`、存储/检索、compaction、reasoning items 或内置工具时才加测这些能力。可接受显式历史不代表具备服务端会话状态；`store: false` 可用不代表检索接口也可用。
- 适配：确认目标客户端确实能消费 Responses 事件，能力目录不会将其误标成只能处理 Chat 的适配器。

## 公共能力与失败语义

| 检查项 | 有意义的通过条件 |
| --- | --- |
| 纯文本与多轮 | 返回可用内容，后续问题能引用前轮信息；日志映射符合预期 |
| 流式文本 | 收到逐步增量和正确终止信号；重建内容与非流式语义一致 |
| 工具调用 | 生成符合 schema 的调用 → 回传假工具结果 → 产出引用结果的回答 |
| 推理 | 支持的档位/开关被接受，输出分离与历史回传符合该协议；不能仅凭思考文字判断开关有效 |
| 结构化输出 | 区分 JSON mode 与严格 schema；用包含 required/enum 等约束的 schema 检验返回值 |
| 多模态 | 用已知答案的小型图片/音频等样本验证理解结果；按需分别测 URL、data URI 或文件输入 |
| 长上下文 | 在实际需要的预算内成功，并记录截断或超限错误；小样本不能证明最大窗口 |
| 取消与中断 | 取消能向上游传播；中途断流/错误不被记录为完整成功，不出现重复拼接输出 |
| 鉴权与错误 | 错误凭证被拒绝；非法模型/参数的错误可诊断，流内错误不会被 HTTP 200 掩盖 |
| 回退 | 可控故障下实际命中预期备用渠道，并保持请求能力和最终日志一致 |

若 usage 缺失，不凭字符数伪造精确 tokens/s；记录不可得项。首字延迟要区分首个 SSE 事件、首个推理输出和首个可见回答。

## 证据与来源

报告保留脱敏后的请求结构、状态码、协议关键字段/事件、实际路由、延迟与终止结果。认证头、Cookie、签名 URL、私钥以及用户真实对话不进入共享报告；优先使用合成探测数据。

协议定义参考官方文档，第三方兼容接口的实现范围还需结合其文档和实测：

- [OpenAI Chat Completions](https://platform.openai.com/docs/api-reference/chat/create)
- [OpenAI Responses](https://platform.openai.com/docs/api-reference/responses/create)
- [Anthropic Messages](https://platform.claude.com/docs/en/api/messages)
