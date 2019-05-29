module namespace EMail = 'de.axxepta.syncrovet.email.Mail';

declare function EMail:sendMail($SSLTLS, $HOST, $MAIL-PORT, $MAIL-USER,
            $MAIL-PWD, $MAIL, $recipient, $subject, $msg)
{
  'sendMail'
};

declare function EMail:sendHTMLMail($SSLTLS, $HOST, $MAIL-PORT, $MAIL-USER,
            $MAIL-PWD, $MAIL, $recipient, $subject, $msg, $msgText)
{
  'sendHTMLMail'
};

declare function EMail:sendImageHTMLMail($SSLTLS, $MAIL-HOST, $MAIL-PORT, $MAIL-USER,
            $MAIL-PWD, $MAIL, $recipient, $subject, $msg, $msgText, $PIM-HOST)
{
  'sendImageHTMLMail'
};