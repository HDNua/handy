# RULES

This file defines the strict rules and guidelines for the AI agent working on the "resume" project.
The AI agent must always refer to this file to ensure consistency in **Workflow, File Management, and Communication**.

## 1. General Workflow & Communication
*   **Language**:
    *   **Always use Korean** for both conversation (responses) and documentation.
    *   (Exception: Code variable names or specific technical terms can remain in English).
*   **Documentation Location**:
    *   All common/shared documentation must be placed in **`0_ai/0_global/`** (or its subfolders like `manuals/`).
    *   **Do NOT** create documentation files scattered across other project directories (e.g., inside `res/1_samsung/...`).
*   **Mermaid Diagrams**:
    *   **Always separate Mermaid diagrams** into their own dedicated `.md` files (e.g., `*_Diagrams.md`).
    *   Do not embed large Mermaid blocks inside the main text-heavy documents; link to them instead.

## 2. Task Management System
Maintain a strict task lifecycle using the following directories:

*   **Active Tasks**:
    *   Location: **`0_ai/0_global/active_tasks/`**
    *   Only currently in-progress or planned tasks reside here.
    *   Format: `TASK_{Number}_{Description}.md`
*   **Archived Tasks**:
    *   Location: **`0_ai/0_global/archived_tasks/`**
    *   Move completed tasks here.
*   **Development Logs**:
    *   Location: **`0_ai/0_global/dev_logs/`**
    *   When a task is completed/archived, create a log file here summarizing the work done.

## 3. Writing Guidelines (Tone & Style)
*   **Professionalism**: All content must be professional, clear, and concise.
*   **Objectivity**: Focus on facts, numbers, and engineering logic.
*   **Terminology**: Use industry-standard terms (AXI, UVM, HBM, TDD, OOP, VIP) correctly.

## 4. Promotion Application (승격 지원서) Specific Rules
When asked to write a promotion application (승격 지원서), adhere to the following strict constraints:

1.  **Avoid Hyperbole**:
    *   **NEVER** use exaggerated adjectives such as "획기적으로" (groundbreakingly), "혁신적인" (innovative), or "탁월한" (outstanding).
    *   Instead, use specific metrics (e.g., "O% 개선", "시간 단축").
2.  **Length Constraint**:
    *   The total length MUST be **between 900 and 1000 Korean characters (ja)** including spaces.
3.  **Formatting**:
    *   No unnecessary paragraph breaks. Dense text is preferred.
    *   **Do NOT** include greetings or closing remarks (e.g., "감사합니다").
    *   Start directly with the core content.
4.  **Narrative Structure**:
    *   Problem (Challenge) -> Action (Solution) -> Result (Impact).
