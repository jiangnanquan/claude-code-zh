import { describe, expect, mock, test, tier } from 'claude-code/testing'
import { duration, groupLine, register, spinnerWord, tr, trDesc, trWhole } from '../hooks/register.tsx'

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

  test('trDesc：命中即返回译文；未命中返回 undefined（供 command.describe 分辨）', () => {
    expect(trDesc(D, 'Exit the CLI')).toBe('退出 CLI')
    // 关键回归：patterns 必须在这条路径上生效，否则带运行时变量的描述永远译不到
    expect(trDesc(D, 'Set theme to dark')).toBe('已设置 theme → dark')
    const d2 = {
      ...D,
      patterns: [{ re: '^Set the AI model for Claude Code \\(currently (.+)\\)$',
                   to: '设置 Claude Code 使用的 AI 模型（当前：$1）' }],
    }
    expect(trDesc(d2, 'Set the AI model for Claude Code (currently opus-4)'))
      .toBe('设置 Claude Code 使用的 AI 模型（当前：opus-4）')
    expect(trDesc(D, 'a phrase nobody translated')).toBeUndefined()
    // ANSI 也要在查表前剥掉
    expect(trDesc(D, '\u001b[36mExit the CLI\u001b[39m')).toBe('退出 CLI')
  })

  test('spinnerWord：已中文一律放行（不覆盖用户 spinnerVerbs）；仅英文才接替', () => {
    // 关键回归：用户用官方 settings.json 的 spinnerVerbs 配了自定义中文动词时，
    // 必须原样放行 —— 否则会被固定词表换成「思考中」，属体验退化。
    expect(spinnerWord(D, 'thinking', '烘焙中')).toEqual({ word: '烘焙中', missed: false })
    expect(spinnerWord(D, 'thinking', '焯水ing')).toEqual({ word: '焯水ing', missed: false })
    // 仍是英文 ⇒ 用词典
    expect(spinnerWord(D, 'thinking', 'Thinking')).toEqual({ word: '思考中', missed: false })
    // 仍是英文且词典没有 ⇒ 放行并标记 missed（供 /cc-zh-dump 收集）
    expect(spinnerWord(D, 'brainstorming', 'Brainstorming')).toEqual({ word: 'Brainstorming', missed: true })
    // 无词可依时保持 undefined 语义
    expect(spinnerWord(D, 'brainstorming', undefined)).toEqual({ word: undefined, missed: true })
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
