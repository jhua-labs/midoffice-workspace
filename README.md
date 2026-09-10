# midoffice-workspace —— Brownfield Workshop 起点(双 repo 版)

这是一套 **AIDLC × BMAD brownfield workshop 的起点项目**:一个"已经在跑的老系统",供你在不破坏既有功能的前提下做增量。

它刻意模拟了一种很常见的真实处境:**前端和后端由不同团队维护、代码在不同的 repo 里**,而一次业务增量需要同时落到两边。

> ⚠️ **这不是可参考的生产代码。** 里面有一批**故意保留的技术债**(明文存储密码、订单表的外键缺失、状态字段无约束、只做认证不做授权),它们是练习材料的一部分 —— brownfield 的真实感来自继承现状,而不是一个干净的样板。请不要把这里的任何写法当作最佳实践,也不要基于它做安全评估。

---

## 一、布局

```
midoffice-workspace/          ← 规划 repo。BMAD 的 project-root 就在这里
  _bmad/                      ← BMAD 配置(共享)
  _bmad-output/               ← PRD、架构、Epic、story spec、测试产物(运行后生成)
  docs/                       ← 既有系统的现状文档(运行后生成)
  requirements/prd-input/     ← PRD 输入
  midoffice-api/              ← 独立 git repo:后端
  midoffice-web/              ← 独立 git repo:前端
```

**三个 repo,各自独立版本管理。** 规划 repo 不跟踪两个代码 repo(见 `.gitignore`),它只承载**所有角色共读**的规划产物。

为什么这么摆:BMAD 的 `{project-root}` 是**单数**,而且从**当前工作目录**解析。所有会话都在工作区根跑,规划产物才会集中落在一处;两个代码 repo 作为子目录存在,是为了让一次跨前后端的增量能在同一个工作区里完成。

| 产物 | 落点 | 属于哪个 repo |
|---|---|---|
| story 文件、spec、epic context、状态表、测试产物 | `_bmad-output/` | **规划 repo**(共享) |
| 后端代码、SQL、单元/集成测试 | `midoffice-api/src/...` | 后端 repo |
| 前端代码、E2E | `midoffice-web/src/...` | 前端 repo |

---

## 二、准备

**环境要求(写版本,不写路径 —— 路径每台机器不一样,由你自己的环境提供):**

| | 要求 |
|---|---|
| JDK | **21**。⚠️ 用更高版本会出现"假通过":编译按 21 的 release 走,但运行时行为没在 21 上验证过 |
| Node.js | 20 或更高 |
| BMAD | **6.10.0**(本起点的 `_bmad/` 配置按这一版生成) |
| Coding Agent | AWS 的 Coding Agent kiro-cli(按现场提供的认证方式与参数完成登录) |

**把三个 repo 摆成上面的布局** —— 克隆规划 repo 之后跑一次 `setup.sh`:

```bash
git clone <midoffice-workspace 的地址>
cd midoffice-workspace
./setup.sh <github-owner>       # 克隆两个代码 repo + 检查环境
```

脚本会把两个代码 repo 克隆到**必须的目录名** `midoffice-api` / `midoffice-web`(规划 repo 的 `.gitignore` 按这两个名字排除它们),然后逐项检查 JDK / Maven / Node / BMAD 并告诉你缺什么。它**不会覆盖任何已存在的目录**,重复跑是安全的。

**装 BMAD。** `.kiro/`(约 11MB 的 skill 文件)和 `_bmad/`(它生成的配置)**都不进 git** —— 它们属于每台机器,配置里还含安装者姓名一类的本机信息。在**工作区根**安装 BMAD 6.10.0,然后核对这几个取值:

| 配置项 | 取值 | 说明 |
|---|---|---|
| `project_name` | `midoffice` | |
| `document_output_language` / `communication_language` | `Chinese` | 换成你们团队的语言也可以,但**全组要一致**,否则产物中英混杂 |
| `output_folder` | `{project-root}/_bmad-output` | 保持默认。**必须是相对 `{project-root}` 的写法**,不要填成绝对路径 |
| `test_stack_type`(`_bmad/tea/config.yaml`) | `fullstack` | 安装器可能给 `backend`。这个项目前后端都有,填错会让测试架构相关的步骤漏掉前端 |
| `user_name` | 你自己的名字 | 不需要跟别人一致 |

---

## 三、跑起来

所有命令都在**工作区根**执行:

```bash
# 后端(:8080)。JAVA_HOME 指向你自己机器上的 JDK 21
mvn -f midoffice-api/pom.xml spring-boot:run

# 后端测试(起点应为 5 个全绿)
mvn -f midoffice-api/pom.xml test

# 前端(:5173)
npm --prefix midoffice-web install
npm --prefix midoffice-web run dev
```

浏览器打开 http://localhost:5173,用 `alice / alice123` 或 `bob / bob123` 登录。

前端通过 Vite 的 dev-proxy 把 `/api/*` 转发到 `http://localhost:8080`,**零 CORS、零后端改动**。数据库文件会生成在 `midoffice-api/data/`(仓库内,已被忽略)。

---

## 四、双 repo 带来的两条约定

这两条不是可选的风格问题 —— 不遵守,AI 会写错位置或记错基线。

**1. 所有代码路径都要带 repo 前缀。**
工作区根下**没有** `src/`。所以 spec 的 Scope、受保护路径、架构的组件归属表,一律写全:

- ✅ `midoffice-api/src/main/java/...`
- ❌ `src/main/java/...` —— 会解析到不存在的 `<工作区>/src/`

**2. 每个 story 只属于一个 repo。**
跨前后端的垂直切片要拆成"后端 story + 前端 story",**API 契约是交接物**。代码的 commit 由人在对应的代码 repo 里做 —— 在工作区根提交只会提交到规划 repo,既抓不到代码改动,又可能把规划产物当成本次变更提交进去。

---

## 五、多人多机共享

规划产物靠 git 共享(agent 需要本地文件才能读 PRD 和架构)。有两点要留意:

- **状态跟踪表是唯一一份所有人都写的文件**,跨机器容易冲突。约定:谁跑完 story 谁改、改完立刻 push,把冲突窗口压到最小;或者约定它不进 git,由一个人持有权威副本。`.gitignore` 第 4 节里留了开关。
- **有些生成的产物内嵌了本机绝对路径**(扫描报告、评审过程记录、本地测试运行结果),跨机器 clone 后这些路径失效,已在 `.gitignore` 里排除。状态表里的 `story_location` 字段也是绝对路径,可以手工改成相对路径 —— 没有任何工具会解析这个字段,改了不影响功能。

---

## 六、这个起点长什么样

- **后端**:JWT **只做认证、没有角色概念**;任何登录用户都能列出全部用户、都能删除任意订单。见 `midoffice-api/README.md`。
- **前端**:一个**已经能跑**的 SPA,登录 + 订单表格 + 删除按钮 + 用户面板,**尚无任何角色门控**。见 `midoffice-web/README.md`。
- **数据库**:嵌入式 H2 文件库,`users` 表**故意没有 role 列** —— 于是"加角色"变成一次**给已有数据的表加列并回填**的真实迁移,而不是从零建表。

增量做什么、怎么做,由你带来的需求和现场的 PRD 澄清决定;这个 repo 只负责提供一个可信的"昨天"。
