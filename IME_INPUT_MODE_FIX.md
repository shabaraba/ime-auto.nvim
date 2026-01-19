# IME入力モード不一致問題の修正

## 問題の症状

**JISキーボード環境で発生**:
- メニューバーのIME表示: 日本語（例: Google Japanese Input）
- 実際の入力: 英字しか入力できない
- 発生タイミング: 数回のInsert/Normalモード切り替え後

**USキーボード環境では問題なし**

## 根本原因

### Carbon APIの2つの制限

1. **Input Source IDのみ制御可能**
   - `TISSelectInputSource()` は Input Source ID（例: `com.google.inputmethod.Japanese.base`）を切り替える
   - しかし、その中の**入力モード**（ひらがな/英数）は制御できない

2. **入力モードとInput Source IDは別物**
   ```
   Input Source ID: com.google.inputmethod.Japanese.base
   ├─ 入力モード: ひらがな  ← これを制御する方法がない
   └─ 入力モード: 英数      ← これを制御する方法がない
   ```

### なぜUSキーボードでは問題が起きないか

- USキーボードでは、Input Source IDの切り替えと同時に入力モードも自動的に切り替わる
- JISキーボードでは、Input Source IDが切り替わっても入力モードが前のまま残る

## 解決策

### キーボードタイプの検出

```swift
func isJISKeyboard() -> Bool {
    let keyboardType = LMGetKbdType()
    return keyboardType == 40 || keyboardType == 41
}
```

### JISキーボードでのみ入力モード強制

```swift
if isJISKeyboard() {
    if isJapaneseIME(targetID) {
        sendKanaKey()  // かなキー（0x68）を送信 → ひらがなモード
    } else if isEnglishIME(targetID) {
        sendEisuKey()  // 英数キー（0x66）を送信 → 英数モード
    }
}
```

### キーイベントの送信

CGEventを使用してキーボードイベントをシミュレート:

```swift
func sendEisuKey() {
    let keyCode: CGKeyCode = 0x66  // 英数キー

    // Key down
    if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
        keyDownEvent.post(tap: .cghidEventTap)
    }
    usleep(10000)

    // Key up
    if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
        keyUpEvent.post(tap: .cghidEventTap)
    }
    usleep(20000)
}
```

## 動作フロー

### JISキーボードの場合

```
1. Input Source IDを切り替え（例: ABC → Japanese）
2. 50ms待機
3. 切り替え成功を検証（最大3回リトライ）
4. かなキー（0x68）を送信
5. 入力モードが強制的にひらがなモードに
```

### USキーボードの場合

```
1. Input Source IDを切り替え（例: ABC → Japanese）
2. 50ms待機
3. 切り替え成功を検証（最大3回リトライ）
4. キーイベント送信をスキップ（不要）
```

## パフォーマンス影響

- **USキーボード**: 50ms〜200ms（従来通り）
- **JISキーボード**: 80ms〜230ms（+30ms for キーイベント）
- **体感への影響**: なし（人間の反応時間 > 200ms）

## デバッグ方法

### デバッグログの確認

```bash
export IME_AUTO_DEBUG=1
nvim

# ログを確認
cat ~/.local/share/nvim/ime-auto/debug.log
```

### 期待されるログ出力

**JISキーボード**:
```
[switchToInputSource] JIS keyboard detected - Sending Kana key to force Hiragana mode
[switchToInputSource] JIS keyboard detected - Sending Eisu key to force English mode
```

**USキーボード**:
```
[switchToInputSource] Non-JIS keyboard detected - Skipping key event (not needed)
```

## 実装ファイル

- `swift/ime-tool.swift`
  - `isJISKeyboard()` - キーボードタイプ検出
  - `sendEisuKey()` / `sendKanaKey()` - キーイベント送信
  - `switchToInputSource()` - 条件付きでキーイベント送信

## テスト方法

### JISキーボード環境でのテスト

1. Google Japanese Inputなど日本語IMEをインストール
2. Neovimでime-autoを有効化
3. Insert ↔ Normal を3-4回繰り返す
4. 日本語入力が正しく動作することを確認

### USキーボード環境でのテスト

1. 同様の手順でテスト
2. ログに "Non-JIS keyboard detected" が出力されることを確認
3. 従来通り動作することを確認

## 既知の制限事項

1. **JISキーボード以外のキーボード**
   - 現在はJIS (40, 41) とUS (その他) のみ対応
   - ISOキーボードなど他のタイプは未テスト

2. **カスタムキーバインド**
   - ユーザーが`英数`/`かな`キーをカスタマイズしている場合は動作しない
   - この場合は `forceInputMode = false` に設定する必要がある（将来の設定項目）

3. **セキュリティ**
   - CGEventの送信には適切な権限が必要
   - macOS 10.15以降では「アクセシビリティ」権限が必要な場合がある

## まとめ

この修正により、JISキーボード環境でのIME入力モード不一致問題が解決されました：

✅ **Input Source ID切り替えの完了を保証**（50ms待機+リトライ）
✅ **JISキーボードでの入力モード強制**（英数/かなキー送信）
✅ **USキーボードでは従来通り動作**（キーイベント送信なし）
✅ **パフォーマンス影響は最小限**（+30ms程度）

---

**修正日**: 2026-01-19
**対象バージョン**: v1.x.x以降
**影響範囲**: macOS JISキーボード環境のみ
