---
title: 记一次 GitHub Pages 自定义域名并启用 HTTPS 的折腾经历
date: 2026-05-21 14:00:00
tags:
  - GitHub Pages
  - Hexo
  - 域名
  - HTTPS
  - Cloudflare
categories: 折腾记录
cover: /img/error-page.png
description: 把 Hexo 博客从 iscaozilong.github.io 换成自定义域名 blog.dragoncao.com，本以为几分钟搞定，结果在 HTTPS 证书签发和 Enforce HTTPS 的环节踩了好几个坑，记录完整流程与解决方案。
---

> 刚把 Hexo 博客挂上 GitHub Pages，手里恰好有个闲置域名，就想把 `iscaozilong.github.io` 换成 `blog.dragoncao.com`。本以为几分钟就能搞定，没想到前前后后踩了几个坑，尤其是 HTTPS 和 Enforce HTTPS 那个环节差点把我绕晕。  
> 这篇文章会把完整流程、踩坑记录和最终解决方案都写出来，既是自己的备忘，也希望能帮到同样用 Hexo + GitHub Pages 的朋友。

---

## 背景

- 博客框架：Hexo
- 托管平台：GitHub Pages（仓库名 `iscaozilong.github.io`）
- 目标域名：`blog.dragoncao.com`
- 需求：输入 `blog.dragoncao.com` 能直接访问博客，并且全程 HTTPS 小绿锁

---

## 第一步：基础配置（理论步骤）

按照 GitHub 官方文档和网上的常规教程，自定义域名总共需要三步：

### 1. 在 GitHub 仓库中添加 CNAME 文件
在博客源文件目录下新建一个名为 `CNAME` 的文件（全部大写，没有后缀），里面写入一行：

```
blog.dragoncao.com
```

注意不要带 `http://` 或 `https://`，只写域名本身。

**对于 Hexo 用户，这个文件一定要放在 `source` 文件夹下**，比如 `source/CNAME`。  
因为 Hexo 在 `generate` 时会直接把 `source` 里的文件原样复制到 `public` 目录，再配合 `hexo-deployer-git` 插件部署到 GitHub 的 `master`/`main` 或 `gh-pages` 分支。  
如果直接把 CNAME 放在博客根目录，部署后会被覆盖丢失，自定义域名就会失效（这个坑后面会详细说）。

### 2. 到 DNS 服务商添加 CNAME 记录
登录域名管理后台（阿里云、腾讯云、Cloudflare 等），添加一条 CNAME 记录：

| 记录类型 | 主机记录 | 记录值 |
|---------|--------|--------|
| CNAME   | `blog` | `iscaozilong.github.io` |

解析生效后，访问 `blog.dragoncao.com` 就会指向 GitHub Pages 的服务器。

### 3. 在 GitHub 仓库设置里绑定域名
进入仓库的 **Settings → Pages**，在 **Custom domain** 输入框中填入 `blog.dragoncao.com`，点击 Save。  
之后 GitHub 会进行 DNS 检查，通过后就可以勾选 **Enforce HTTPS** 来强制开启 HTTPS。

---

## 踩坑一：填完自定义域名直接 404

按照教程走完前三步，兴冲冲打开 `https://blog.dragoncao.com`，结果：

> **404**  
> There isn't a GitHub Pages site here.

第一反应是 DNS 还没生效，等了几分钟再试，依然 404。

### 排查过程

1. **检查 CNAME 文件**  
   到 GitHub 仓库的 `master` 分支根目录找 CNAME 文件，发现它还在，内容是 `blog.dragoncao.com`，没错。

2. **检查 DNS 解析**  
   用 `dig blog.dragoncao.com` 命令（或在线工具）查看，返回的 CNAME 已经是 `iscaozilong.github.io`，说明解析也没问题。

3. **检查 GitHub Pages 发布状态**  
   打开仓库的 **Actions** 标签，发现 `pages-build-deployment` 工作流显示绿色 ✅，并且提示已经成功部署。  
   直接访问 `https://iscaozilong.github.io`，可以正常显示博客 —— 说明源站本身没问题。

4. **重新绑定域名**  
   干脆清空 Custom domain 再重新填入，保存后等了一会儿，DNS check successful 出现了，但依然 404。

后来仔细看，发现虽然 DNS check 通过了，但 **Enforce HTTPS 始终是灰色的**，无法勾选。提示说：

> Enforce HTTPS — Unavailable for your site because your domain is not properly configured to support HTTPS

也就是说，证书没下来。

---

## 踩坑二：证书申请卡住，HTTP 通 HTTPS 不通

继续等了一段时间后，发现通过 `http://blog.dragoncao.com` 居然能访问了（虽然浏览器会提示不安全），但是 `https://` 仍然不行。  
看来问题是出在 SSL 证书签发这一步。

### 又一轮排查

1. **怀疑 CDN 代理冲突**  
   我用的 DNS 服务商（Cloudflare）默认开启了 CDN 代理（橙色云朵）。查阅文档发现，GitHub 为自定义域名申请 Let's Encrypt 证书时，需要直接验证域名的 DNS 记录，如果开了代理，GitHub 看到的是 Cloudflare 的 IP，而不是你的真实记录，证书会无限期卡住。  
   于是我暂时关掉那条 CNAME 记录的代理（点击云朵变成灰色，仅 DNS 模式），等待 10 分钟。

2. **手动重新触发证书申请**  
   清空 Custom domain 保存，再重新填入 `blog.dragoncao.com` 保存，强迫 GitHub 重新验证并申请证书。

3. **等待 + 耐心**  
   官方说最长可能需要 24 小时，实际又等了大概半小时，发现 Settings → Pages 里的 **Enforce HTTPS 选项终于亮了**！  
   此时通过 `https://blog.dragoncao.com` 已经可以正常访问，证书签发成功。

---

## 踩坑三：勾选 Enforce HTTPS 后反而 404，取消勾选却正常

这才是最迷惑的反转。  
证书下来了，勾选 **Enforce HTTPS** 是必须的一步（强制所有 HTTP 流量跳转到 HTTPS）。  
然而勾上之后一刷新 —— 又是 **404**！  
而且连原本能访问的 `http://` 也会自动跳转到 `https://` 然后 404。

赶紧取消勾选，再试 `https://`，居然**又恢复正常了**，而且 HTTP 访问不会自动跳转，但可以手动输入 `https://` 正常打开。  
这就很离谱：**不强制 HTTPS，反而能正常用 HTTPS；一强制就 404。**

### 原因分析（根据查阅的资料和个人理解）

GitHub 的 Enforce HTTPS 功能会在 CDN 层面开启强制重定向，这个过程会对域名绑定进行更严格的二次校验。  
可能是以下几个原因触发校验失败：

- **CNAME 文件末尾有不可见的空格或换行**（虽然肉眼看着没问题）
- **部署分支与 Pages 设置不完全同步**（比如 Hexo 部署到 `gh-pages` 分支，但 Settings 里选的 `master`）
- **GitHub 自身的 CDN 缓存或节点同步延迟**，导致启用强制 HTTPS 的那段时间，部分边缘节点还没更新到最新构建
- **DNS 记录的 TTL 缓存**，强制 HTTPS 节点解析到的地址与不强制时不同

但不管具体原因是什么，核心事实是：**取消勾选 Enforce HTTPS，网站反而稳定可用；勾上就炸。**

## 最终解决方案

既然 GitHub 官方的强制 HTTPS 和我八字不合，那就换一条路。目标仍然要实现：

1. 全站 HTTPS 加密
2. 输入 `http://` 能自动跳转到 `https://`

### 方案一：使用 Cloudflare 实现强制 HTTPS（我已采用）

如果你和我一样 DNS 用的是 Cloudflare，这件事会非常简单：

1. 保持 CNAME 记录的代理为**橙色云朵开启**（CDN 模式）。
2. 进入 Cloudflare 的 **SSL/TLS** → **概述**，加密模式选择 **Full** 或 **Full (strict)**。  
   Full 模式下，Cloudflare 到源站也走 HTTPS，能保证整条链路加密。
3. 在 **规则** → **页面规则** 里创建一条规则：  
   - URL：`http://*blog.dragoncao.com/*`  
   - 设置：**始终使用 HTTPS**  
   这样所有到 `blog.dragoncao.com` 的 HTTP 请求都会被 Cloudflare 边缘节点 301 重定向到 HTTPS，完全不依赖 GitHub 的 Enforce HTTPS。

这样既保证了强制跳转，又不会触发 GitHub 的 404 bug，而且因为走了 Cloudflare 的 CDN，国内访问速度也会提升不少。

### 方案二：如果不用 Cloudflare

可以在博客源码里加一段 JavaScript 来实现客户端重定向（不推荐，对 SEO 不友好）：

```html
<script>
  if (location.protocol === 'http:') {
    location.href = 'https://' + location.host + location.pathname;
  }
</script>
```

放到 Hexo 的 `source` 文件夹下的某个模板里，或直接写到 `layout` 文件中。

但更推荐用 DNS 服务商提供的 URL 转发/重定向功能（如果有）。

---

## Hexo 用户特别注意：CNAME 文件千万别放错位置

整个过程中，Hexo 部署时最容易出的一个坑就是 **CNAME 文件丢失**。

- **正确位置**：放在 Hexo 博客根目录的 `source` 文件夹下，比如 `source/CNAME`。
- **原因**：执行 `hexo generate` 时，`source` 里的所有文件都会被复制到 `public` 目录，最终 `hexo deploy` 会把 `public` 里的内容推送到 GitHub 的分支（一般是 `master` 或 `gh-pages`）。  
  如果直接放在博客根目录，`public` 目录里不会有这个文件，那么部署后 GitHub 仓库里就没有 CNAME 文件，自定义域名就会失效，每次部署完都得手动去 Settings 里重新填一遍域名。
- **验证方法**：部署完成后，去 GitHub 仓库对应的分支（比如 `master`）根目录，确认 CNAME 文件存在，且内容正确。

---

## 总结

回顾整个折腾过程，关键时间点如下：

1. **DNS check successful** 出现后，HTTP 可访问，HTTPS 需要等证书。
2. 如果使用了 CDN 代理（Cloudflare 橙色云朵），要先关掉才能顺利签发证书。
3. 证书签发后 Enforce HTTPS 不要立刻勾，先观察 `https://` 能不能直接访问。
4. 如果勾上 Enforce HTTPS 就 404，果断放弃，换用 Cloudflare 规则实现强制跳转。

最终我的博客已经稳稳地跑在 `https://blog.dragoncao.com` 上，全站 HTTPS，访问速度也很快。虽然中间卡了好几次，但问题全部解决后的舒畅感，可能就是折腾的乐趣吧。

希望这篇记录能给同样用 Hexo + GitHub Pages 的你一些参考，少走弯路。如果有其他奇技淫巧或更好的方案，欢迎交流。

---

*折腾日期：2026年5月*  
*环境：Hexo 6.x + GitHub Pages + Cloudflare DNS*
