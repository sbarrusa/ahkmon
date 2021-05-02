DeepLAPI(Type) {

  ;; Don't run if clipboard does not contain text
  if DllCall("IsClipboardFormatAvailable", "uint", 1) {

    if (RequireFocus = 0) {
      keepGoing = 1
    }
    
    if (RequireFocus = 1) {
      if WinActive("ahk_exe DQXGame.exe") {
        keepGoing = 1
      }
    }

    if (keepGoing = 1) {
        Process, Exist, DQXGame.exe

      if ErrorLevel {
        Process, Exist, DQ10Dialog.exe

        if ErrorLevel {

          ;; Get number of items we'll be iterating over. Using this at the end.
          numberOfClipboardItems := StrSplit(Clipboard, "`r`n`r`n")

          ;; Sanitize Clipboard string
          Clipboard := StrReplace(Clipboard, "「","")
          parsedString :=

          ;; Open database connection
          dbFileName := A_ScriptDir . "\dqxtrl.db"
          db := New SQLiteDB

          ;; Iterate through each line that DQDialog returns.
          ;; Don't translate all in one go
          for index, sentence in StrSplit(Clipboard, "`r`n`r`n") {

            ;; See if we have an entry available to grab from before sending the request to DeepL.
            result :=
            query := "SELECT en FROM dialog WHERE jp = '" . sentence . "';"

            if !db.OpenDB(dbFileName)
              MsgBox, 16, SQLite Error, % "Msg:`t" . db.ErrorMsg . "`nCode:`t" . db.ErrorCode

            if !db.GetTable(query, result)
              MsgBox, 16, SQLite Error, % "Msg:`t" . db.ErrorMsg . "`nCode:`t" . db.ErrorCode

            result := result.Rows[1,1]

            ;; If no matching line was found in the database, query DeepL.
            if !result {

              ;; If not found locally, make a call to DeepL API to get
              ;; translated text.
              Body := "auth_key="
                    . DeepLAPIKey
                    . "&source_lang=JA"
                    . "&target_lang=EN"
                    . "&text="
                    . sentence

              oWhr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
              oWhr.Open("POST", "https://api-free.deepl.com/v2/translate", 0)
              oWhr.SetRequestHeader("User-Agent", "DQXTranslator")
              oWhr.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")
              oWhr.Send(Body)

              GuiControl, 2:Text, Clip, "..."
              oWhr.WaitForResponse()
        
              ;; Translated dialog text
              jsonResponse := JSON.Load(oWhr.ResponseText)
              translatedText := jsonResponse.translations[1].text

              ;; Sanitize text that comes back from DeepL
              translatedText := StrReplace(translatedText, "ã"," ")
              translatedText := StrReplace(translatedText, "'","''")  ;; Escape single quotes found in contractions before sending to database

              ;; Write new entry to the database
              query := "INSERT INTO dialog (jp, en) VALUES ('" . sentence . "', '" . translatedText . "');"
              db.Exec("BEGIN TRANSACTION;")

              if !db.Exec(query)
                MsgBox, 16, SQLite Error, % "Msg:`t" . db.ErrorMsg . "`nCode:`t" . db.ErrorCode

              db.Exec("COMMIT TRANSACTION;")

              ;; Remove escaped single quotes before sending to overlay
              translatedText := StrReplace(translatedText, "''","'")
              GuiControl, 2:Text, Clip, %translatedText%

              if (Log = 1)
                FileAppend, %sentence%||%translatedText%`n, textdb.out, UTF-16
            }

            else {
              GuiControl, 2:Text, Clip, %result%
            }

            ;; Determine whether to listen for joystick or keyboard keys
            ;; to continue the dialog
            if numberOfClipboardItems.Count() > 1 {
              if (JoystickEnabled = 1) {
                Input := GetKeyPress(JoystickKeys)
              }
              else {
                Input := GetKeyPress(KeyboardKeys)
              }
            }
          }

          ;; Close database connection
          db.CloseDB()

        }
      }
    }
  }
}
