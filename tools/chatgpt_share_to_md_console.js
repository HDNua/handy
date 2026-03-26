(() => {
  const SKIP_TAGS = new Set([
    "button",
    "canvas",
    "dialog",
    "input",
    "noscript",
    "script",
    "select",
    "style",
    "svg",
    "textarea",
  ]);

  const BLOCK_TAGS = new Set([
    "address",
    "article",
    "aside",
    "blockquote",
    "details",
    "div",
    "dl",
    "fieldset",
    "figcaption",
    "figure",
    "footer",
    "form",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "header",
    "hr",
    "li",
    "main",
    "nav",
    "ol",
    "p",
    "pre",
    "section",
    "summary",
    "table",
    "tbody",
    "thead",
    "tr",
    "ul",
  ]);

  function normalizeText(text) {
    return String(text || "")
      .replace(/\u00a0/g, " ")
      .replace(/\r/g, "");
  }

  function sanitizeInline(text) {
    return normalizeText(text).replace(/\s+/g, " ").trim();
  }

  function cleanBlock(text) {
    return normalizeText(text)
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  function slugify(text) {
    const slug = normalizeText(text)
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
    return slug || "chatgpt-share";
  }

  function isHidden(node) {
    if (!(node instanceof Element)) {
      return false;
    }

    if (node.hidden || node.getAttribute("aria-hidden") === "true") {
      return true;
    }

    const style = window.getComputedStyle(node);
    return style.display === "none" || style.visibility === "hidden";
  }

  function isTopLevelSelectorMatch(node, selector) {
    return node.matches(selector) && !node.parentElement?.closest(selector);
  }

  function detectLanguage(node) {
    const classNames = [
      node.className,
      node.querySelector("code")?.className || "",
    ]
      .join(" ")
      .split(/\s+/)
      .filter(Boolean);

    for (const className of classNames) {
      const match = className.match(/(?:language|lang)-([a-z0-9_+-]+)/i);
      if (match) {
        return match[1].toLowerCase();
      }
    }

    return "";
  }

  function renderPlainText(node) {
    if (!node) {
      return "";
    }

    if (node.nodeType === Node.TEXT_NODE) {
      return normalizeText(node.textContent || "");
    }

    if (!(node instanceof Element) || isHidden(node) || SKIP_TAGS.has(node.tagName.toLowerCase())) {
      return "";
    }

    const tag = node.tagName.toLowerCase();
    if (tag === "br") {
      return "\n";
    }

    const joined = Array.from(node.childNodes).map(renderPlainText).join("");
    if (BLOCK_TAGS.has(tag)) {
      return `\n${joined}\n`;
    }

    return joined;
  }

  function renderTable(node) {
    const rows = Array.from(node.querySelectorAll("tr"))
      .map((row) =>
        Array.from(row.querySelectorAll("th, td")).map((cell) =>
          sanitizeInline(renderPlainText(cell))
        )
      )
      .filter((cells) => cells.length > 0);

    if (!rows.length) {
      return "";
    }

    const header = rows[0];
    const separator = header.map(() => "---");
    const body = rows.slice(1);
    const lines = [
      `| ${header.join(" | ")} |`,
      `| ${separator.join(" | ")} |`,
      ...body.map((row) => `| ${row.join(" | ")} |`),
    ];

    return `\n\n${lines.join("\n")}\n\n`;
  }

  function renderList(node, ordered, depth = 0) {
    const indent = "  ".repeat(depth);
    const items = Array.from(node.children)
      .filter((child) => child.tagName?.toLowerCase() === "li")
      .map((item, index) => {
        const fragments = [];

        for (const child of item.childNodes) {
          if (
            child instanceof Element &&
            (child.tagName.toLowerCase() === "ul" || child.tagName.toLowerCase() === "ol")
          ) {
            const nested = renderList(
              child,
              child.tagName.toLowerCase() === "ol",
              depth + 1
            ).trimEnd();
            if (nested) {
              fragments.push(`\n${nested}`);
            }
            continue;
          }

          fragments.push(renderNode(child, depth));
        }

        const marker = ordered ? `${index + 1}.` : "-";
        const text = cleanBlock(fragments.join(""));
        if (!text) {
          return "";
        }

        const lines = text.split("\n");
        const firstLine = lines.shift() || "";
        const trailing = lines.length
          ? `\n${lines.map((line) => `${indent}   ${line}`).join("\n")}`
          : "";

        return `${indent}${marker} ${firstLine}${trailing}`;
      })
      .filter(Boolean);

    return items.length ? `\n${items.join("\n")}\n` : "";
  }

  function renderBlockquote(node) {
    const text = cleanBlock(Array.from(node.childNodes).map((child) => renderNode(child, 0)).join(""));
    if (!text) {
      return "";
    }

    const quoted = text
      .split("\n")
      .map((line) => (line ? `> ${line}` : ">"))
      .join("\n");

    return `\n\n${quoted}\n\n`;
  }

  function renderPre(node) {
    const codeNode = node.querySelector("code") || node;
    const language = detectLanguage(node);
    const code = normalizeText(codeNode.textContent || "").replace(/\n+$/, "");
    return `\n\n\`\`\`${language}\n${code}\n\`\`\`\n\n`;
  }

  function renderLink(node, depth) {
    const text = cleanBlock(Array.from(node.childNodes).map((child) => renderNode(child, depth)).join("")) || sanitizeInline(node.textContent);
    const href = node.getAttribute("href") || "";
    if (!href) {
      return text;
    }
    return `[${text || href}](${href})`;
  }

  function renderNode(node, depth = 0) {
    if (!node) {
      return "";
    }

    if (node.nodeType === Node.TEXT_NODE) {
      return normalizeText(node.textContent || "");
    }

    if (!(node instanceof Element) || isHidden(node)) {
      return "";
    }

    const tag = node.tagName.toLowerCase();
    if (SKIP_TAGS.has(tag)) {
      return "";
    }

    if (tag === "br") {
      return "\n";
    }

    if (tag === "hr") {
      return "\n\n---\n\n";
    }

    if (/^h[1-6]$/.test(tag)) {
      const level = Number(tag[1]);
      const text = cleanBlock(Array.from(node.childNodes).map((child) => renderNode(child, depth)).join(""));
      return text ? `\n\n${"#".repeat(level)} ${text}\n\n` : "";
    }

    if (tag === "pre") {
      return renderPre(node);
    }

    if (tag === "code") {
      if (node.closest("pre")) {
        return normalizeText(node.textContent || "");
      }
      const text = sanitizeInline(node.textContent || "");
      return text ? `\`${text}\`` : "";
    }

    if (tag === "a") {
      return renderLink(node, depth);
    }

    if (tag === "img") {
      const alt = sanitizeInline(node.getAttribute("alt") || "image");
      const src = node.getAttribute("src") || "";
      return src ? `![${alt}](${src})` : alt;
    }

    if (tag === "blockquote") {
      return renderBlockquote(node);
    }

    if (tag === "ul") {
      return renderList(node, false, depth);
    }

    if (tag === "ol") {
      return renderList(node, true, depth);
    }

    if (tag === "table") {
      return renderTable(node);
    }

    const children = Array.from(node.childNodes).map((child) => renderNode(child, depth)).join("");

    if (tag === "strong" || tag === "b") {
      const text = cleanBlock(children);
      return text ? `**${text}**` : "";
    }

    if (tag === "em" || tag === "i") {
      const text = cleanBlock(children);
      return text ? `*${text}*` : "";
    }

    if (tag === "del" || tag === "s") {
      const text = cleanBlock(children);
      return text ? `~~${text}~~` : "";
    }

    if (BLOCK_TAGS.has(tag)) {
      const text = cleanBlock(children);
      return text ? `\n\n${text}\n\n` : "";
    }

    return children;
  }

  function resolveTitle() {
    const candidates = [
      document.querySelector("main h1"),
      document.querySelector("h1"),
      document.querySelector("title"),
    ]
      .filter(Boolean)
      .map((node) => sanitizeInline(node.textContent || ""))
      .filter(Boolean);

    const title = candidates[0] || sanitizeInline(document.title || "");
    return title.replace(/\s*-\s*ChatGPT\s*$/i, "") || "ChatGPT Shared Conversation";
  }

  function inferRoleFromNode(node, index) {
    const explicitRole = node.getAttribute("data-message-author-role");
    if (explicitRole) {
      return explicitRole;
    }

    const nestedRole = node.querySelector("[data-message-author-role]")?.getAttribute("data-message-author-role");
    if (nestedRole) {
      return nestedRole;
    }

    const label = sanitizeInline(
      node.querySelector("[aria-label]")?.getAttribute("aria-label") ||
        node.querySelector("img[alt]")?.getAttribute("alt") ||
        ""
    ).toLowerCase();

    if (label.includes("assistant") || label.includes("chatgpt")) {
      return "assistant";
    }

    if (label.includes("user") || label.includes("you")) {
      return "user";
    }

    return index % 2 === 0 ? "user" : "assistant";
  }

  function findMessageNodes() {
    const selectorGroups = [
      "[data-message-author-role]",
      "[data-testid^='conversation-turn-']",
      "main article",
    ];

    for (const selector of selectorGroups) {
      const nodes = Array.from(document.querySelectorAll(selector)).filter((node) =>
        isTopLevelSelectorMatch(node, selector)
      );
      if (nodes.length) {
        return nodes;
      }
    }

    return [];
  }

  function selectContentRoot(node) {
    const selectors = [
      "[data-testid='conversation-turn-content']",
      "[data-testid='message-content']",
      ".markdown",
      "[class*='markdown']",
      "article",
    ];

    for (const selector of selectors) {
      const match = node.querySelector(selector);
      if (match) {
        return match;
      }
    }

    return node;
  }

  function collectMessages() {
    const nodes = findMessageNodes();
    const messages = nodes
      .map((node, index) => {
        const role = inferRoleFromNode(node, index);
        const contentRoot = selectContentRoot(node);
        const content = cleanBlock(renderNode(contentRoot, 0));
        return { role, content };
      })
      .filter((message) => message.content);

    return messages;
  }

  function roleHeading(role) {
    const normalized = String(role || "").toLowerCase();
    if (normalized === "user") {
      return "User";
    }
    if (normalized === "assistant") {
      return "Assistant";
    }
    if (normalized === "system") {
      return "System";
    }
    return normalized ? normalized[0].toUpperCase() + normalized.slice(1) : "Message";
  }

  function buildMarkdown(title, messages) {
    const exportedAt = new Date().toISOString();
    const sections = [
      `# ${title}`,
      "",
      `Source: ${window.location.href}`,
      `Exported: ${exportedAt}`,
      "",
    ];

    for (const message of messages) {
      sections.push(`## ${roleHeading(message.role)}`);
      sections.push("");
      sections.push(message.content);
      sections.push("");
    }

    return `${sections.join("\n").replace(/\n{3,}/g, "\n\n").trim()}\n`;
  }

  function downloadMarkdown(filename, content) {
    const blob = new Blob([content], { type: "text/markdown;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = filename;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
  }

  const title = resolveTitle();
  const messages = collectMessages();

  if (!messages.length) {
    throw new Error("No conversation messages were found on this page.");
  }

  const markdown = buildMarkdown(title, messages);
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filename = `${slugify(title)}-${timestamp}.md`;

  downloadMarkdown(filename, markdown);

  if (navigator.clipboard?.writeText) {
    navigator.clipboard.writeText(markdown).catch(() => {});
  }

  window.__chatgptShareExport = {
    filename,
    markdown,
    messages,
    title,
  };

  console.log(`Saved ${messages.length} messages to ${filename}`);
})();
