import type { Register } from 'claude-code'

// 运行时字符串采样插件（**不是发布物**，只在补词条时用）。
//
// 为什么需要它：`/cc-zh-dump` 的屏幕输出会被渲染器折行、并**吞掉反引号**
// （实测 `` `claude doctor` `` / `` `anthropic` `` 的反引号在渲染时消失），
// 拿它当 exact 的 key 会**静默失配** —— 词典是逐字匹配，错一个字符就永远命中不了。
// 本插件把引擎在真实会话里给出的原值直接落盘，是 key 的权威来源。
//
// 用法：见 tools/README.md。输出固定写到 /tmp/cc-zh-sample/（绝不写仓库或 $HOME）。
//
// ⚠️ 三条实测出来的 mod 运行时约束（不遵守则模块加载失败）：
//   1. `$.fs.write` 并发不安全 —— 每个钩子各自 await 会互相截断（实测写坏过 JSON），
//      须串成一条队列。
//   2. **禁止把 `$` 传进辅助函数**（编译期报 `$ is passed to ...`）。
//   3. `on(...)` 的返回值**不得被保留/返回/从嵌套函数取出**，所以钩子只能逐个内联写，
//      不能用 `const grab = (c) => on('ui.render', { component: c }, ...)` 这类工厂。

const DIR = '/tmp/cc-zh-sample'
const OUT_ALL = `${DIR}/runtime.json`
const OUT_DESC = `${DIR}/describe.json`
const OUT_UI = `${DIR}/ui.json`
const OUT_ERR = `${DIR}/error.txt`

export const register: Register = on => {
  const desc: Record<string, unknown> = {}
  const ui: Record<string, unknown> = {}
  let queue: Promise<unknown> = Promise.resolve()

  on('session.start', async ($, e, next) => {
    try {
      const commands = await $.command.list()
      const config = await $.config.list()
      await $.fs.write(OUT_ALL, JSON.stringify({ commands, config }, null, 1))
      // describe.json / ui.json 由下面的钩子增量覆盖，这里先落一个空壳，
      // 免得钩子没触发时读到上次的残留。
      await $.fs.write(OUT_DESC, '{}')
      await $.fs.write(OUT_UI, '{}')
    } catch (err: any) {
      await $.fs.write(OUT_ERR, String(err?.stack ?? err))
    }
    return next(e)
  })

  // 引擎「列命令的那一刻」给出的 description —— 正是 cc-zh 要拿来做 key 的那个值。
  // 注意：它与 `$.command.list()` 的 description **可能不同**（实测 `/diff` 两处不一样），
  // 而界面显示的是这里这一个，故本文件才是权威。
  on('command.describe', async ($, e, next) => {
    const r = await next(e)
    desc[e.command] = { description: r.description, argumentHint: r.argumentHint ?? null, isHidden: r.isHidden }
    const snapshot = JSON.stringify(desc, null, 1)
    queue = queue.then(() => $.fs.write(OUT_DESC, snapshot)).catch(() => {})
    await queue
    return r
  })

  on('config.describe', async ($, e, next) => {
    const r = await next(e)
    desc[`@config:${e.key}`] = { label: r.label, description: r.description }
    const snapshot = JSON.stringify(desc, null, 1)
    queue = queue.then(() => $.fs.write(OUT_DESC, snapshot)).catch(() => {})
    await queue
    return r
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    ui['PromptHint'] = { hint: e.props.hint }
    const snapshot = JSON.stringify(ui, null, 1)
    queue = queue.then(() => $.fs.write(OUT_UI, snapshot)).catch(() => {})
    await queue
    return next(e)
  })

  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    ui['Spinner'] = { mode: e.props.mode, word: e.props.word, message: e.props.message, surface: e.surface }
    const snapshot = JSON.stringify(ui, null, 1)
    queue = queue.then(() => $.fs.write(OUT_UI, snapshot)).catch(() => {})
    await queue
    return next(e)
  })

  on('ui.render', { component: 'InfoNotice' }, async ($, e, next) => {
    ui['InfoNotice'] = { text: e.props.text }
    const snapshot = JSON.stringify(ui, null, 1)
    queue = queue.then(() => $.fs.write(OUT_UI, snapshot)).catch(() => {})
    await queue
    return next(e)
  })

  on('ui.render', { component: 'ToolProgress' }, async ($, e, next) => {
    ui['ToolProgress'] = { hint: e.props.hint }
    const snapshot = JSON.stringify(ui, null, 1)
    queue = queue.then(() => $.fs.write(OUT_UI, snapshot)).catch(() => {})
    await queue
    return next(e)
  })

  on('ui.render', { component: 'SessionMode' }, async ($, e, next) => {
    ui['SessionMode'] = { modes: e.props.modes }
    const snapshot = JSON.stringify(ui, null, 1)
    queue = queue.then(() => $.fs.write(OUT_UI, snapshot)).catch(() => {})
    await queue
    return next(e)
  })
}
