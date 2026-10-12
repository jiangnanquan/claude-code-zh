import { describe, expect, mock, test, tier } from 'claude-code/testing'
import { duration, groupLine, register, tr, trWhole } from '../hooks/register.tsx'

tier('user')

// 装配正确性由 `claude plugin validate` 枚举证明（13 个钩子 + $ 调用全部识别）。
// 这里只断言「跑在真实运行时里」的纯逻辑：模块能否加载、词典形状、查表与兜底行为。
// 注意：本层用 on() 设桩的事件，不能与 mod 自身注册的事件重合（会报 registered twice）。
const D = {
  exact: { 'Show help and available commands': '显示帮助和可用命令', 'Exit the CLI': '退出 CLI' },
  spinner: { thinking: '思考中' },
  modes: {},
  patterns: [{ re: '^Set (\\S+) to (.+)$', to: '已设置 $1 → $2' }],
}

describe('cc-zh', () => {
  test('register 是可调用的导出（模块能被真实运行时加载）', () => {
    expect(typeof register).toBe('function')
  })

  test('exact 命中 → 中文', () => {
    expect(tr(D, 'Show help and available commands')).toBe('显示帮助和可用命令')
  })

  test('未命中 → 原样放行，不改写', () => {
    const s = 'a phrase nobody translated'
    expect(tr(D, s)).toBe(s)
  })

  test('ANSI 转义被剥离后再查表', () => {
    expect(tr(D, '\u001b[36mExit the CLI\u001b[39m')).toBe('退出 CLI')
  })

  test('patterns 兜底：Set X to Y → 已设置 X → Y', () => {
    expect(tr(D, 'Set theme to dark')).toBe('已设置 theme → dark')
  })

  test('trWhole：整句译到才接受；含缩写/专有名词仍算译到；半译则放弃', () => {
    expect(trWhole(D, 'Exit the CLI')).toBe('退出 CLI')
    // 全大写缩写（CLI）与专有名词（Claude）不应被误判为「未译完」
    const d3 = { ...D, exact: { ...D.exact, 'Claude is thinking': 'Claude 正在思考' } }
    expect(trWhole(d3, 'Claude is thinking')).toBe('Claude 正在思考')
    // 半译（还剩长英文单词）⇒ 放弃
    const d2 = { ...D, patterns: [{ re: '^Set (\\S+) to (.+)$', to: '已设置 $1' }] }
    expect(trWhole(d2, 'Set theme to dark')).toBeUndefined()
  })

  test('groupLine：已知工具 → 中文摘要；含未知工具 → undefined（交回引擎原文）', () => {
    const line = groupLine([{ tool: 'Read' }, { tool: 'Read' }, { tool: 'Bash' }], false)
    expect(line).toBe('读取 2 个文件，执行 1 条命令')
    expect(groupLine([{ tool: 'Read' }], true)).toBe('读取 1 个文件中')
    expect(groupLine([{ tool: 'Mystery' }], false)).toBeUndefined()
  })

  test('duration：中文时长', () => {
    expect(duration(3000)).toBe('3 秒')
    expect(duration(90_000)).toBe('1 分 30 秒')
    expect(duration(3_600_000)).toBe('1 小时 0 分')
  })

  test('测试环境提供时钟桩与 ui 挂载能力', async ($, on) => {
    mock.clock(on)
    expect(typeof $.ui.mount).toBe('function')
    expect(typeof $.command.describe).toBe('function')
    expect(typeof $.config.describe).toBe('function')
  })
})
