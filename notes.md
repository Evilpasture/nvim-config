## 🛠️ Semantic Navigation (The "Wizard" Basics)

### 1. Small Jumps (Token-Based)

* `w` : Jump to the **start** of the next word (token).
* `e` : Jump to the **end** of the next word.
* `b` : Jump **back** to the start of the word.
* `ge`: Jump **back** to the end of the previous word.

### 2. Precise Target (Character Find)

* `f{char}` : **Find** the next occurrence of `{char}` in the line (e.g., `f;` to jump to the semicolon).
* `t{char}` : Jump **Till** (just before) the next occurrence of `{char}`.
* `;` : Repeat the last `f` or `t` search.
* `,` : Repeat the last `f` or `t` search in reverse.

### 3. Vertical Throughput (The "O(1)" Scroll)

* `<C-d>` : Scroll **Down** half a page (keeps your eyes centered).
* `<C-u>` : Scroll **Up** half a page.
* `G`     : Jump to the **End** of the file.
* `gg`    : Jump to the **Start** of the file.
* `{N}G`  : Jump to line number `{N}`.

### 4. Search & Pair Logic

* `/` : Search forward (type your variable name, hit `Enter`).
* `?` : Search backward.
* `n` : Go to the **Next** search match.
* `N` : Go to the **Previous** search match.
* `%` : Jump between matching pairs (e.g., jump from `{` to `}`). **Crucial for C macros.**

---

## Pro-Tips for C/C++ Devs

* **The "Caps Lock" Swap:** If you haven't yet, remap **Caps Lock** to **Escape**. Your left pinky will thank you, and you'll stay on the home row.
* **Asterisk Search:** Press `*` while the cursor is on a variable. It searches for all other occurrences of that variable in the file.
* **The Jump:** Use `gd` (**G**o to **D**efinition) if you have an LSP set up. It’ll take you straight to the struct or function declaration in your headers.



