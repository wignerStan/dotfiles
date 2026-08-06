import os
import sys, time
from pywinauto import Application

LOG = os.path.join(os.environ['USERPROFILE'], 'winstock-detail.log')
log = open(LOG, 'w', encoding='utf-8')
def w(*a):
    m = ' '.join(str(x) for x in a)
    print(m); log.write(m + '\n'); log.flush()

app = Application(backend='uia').connect(path=r'C:\Weisoft Stock(x64)\WinStock.exe', timeout=30)
wins = app.windows()
w('windows:', len(wins))
for win in wins:
    w('  win:', repr(win.window_text()), '| cls:', win.class_name())
    try:
        for c in win.descendants():
            try:
                ct = c.element_info.control_type
                t = c.window_text()
                if t and ct in ('Text', 'Edit', 'Button', 'Hyperlink'):
                    w('    %s: %r' % (ct, t[:80]))
            except Exception:
                pass
    except Exception as e:
        w('  dump err:', repr(e))
    # click OK if dialog, then wait and re-dump
    try:
        ok = win.child_window(title='确定', control_type='Button')
        if ok.exists(timeout=1):
            w('  -> clicking 确定')
            ok.click()
            time.sleep(8)
            wins2 = app.windows()
            w('  after click, windows:', len(wins2))
            for win2 in wins2[:4]:
                w('    win:', repr(win2.window_text()[:80]), '| cls:', win2.class_name())
    except Exception as e:
        w('  ok-click err:', repr(e))
w('DONE')
log.close()
