import os
import sys, time, subprocess
from pywinauto import Application

LOG = os.path.join(os.environ['USERPROFILE'], 'winstock-final.log')
log = open(LOG, 'w', encoding='utf-8')
def w(*a):
    m = ' '.join(str(x) for x in a)
    print(m); log.write(m + '\n'); log.flush()

w('start')
p = subprocess.Popen([r'C:\Weisoft Stock(x64)\WinStock.exe'], cwd=r'C:\Weisoft Stock(x64)')
w('launched', p.pid)
for i in range(14):
    time.sleep(5)
    try:
        app = Application(backend='uia').connect(path=r'C:\Weisoft Stock(x64)\WinStock.exe', timeout=3)
        wins = app.windows()
        w('t=%ds windows=%d' % (5*(i+1), len(wins)))
        for win in wins[:6]:
            t = win.window_text() or ''
            w('  win:', repr(t[:90]), '| cls:', win.class_name())
            if '无法创建' in t:
                w('  *** ERROR DIALOG PRESENT ***')
        if wins:
            for win in wins[:2]:
                try:
                    for c in win.descendants(control_type='Button')[:12]:
                        tt = c.window_text()
                        if tt: w('    btn:', repr(tt))
                    for c in win.descendants(control_type='Edit')[:6]:
                        tt = c.window_text()
                        if tt: w('    edit:', repr(tt))
                except Exception as e:
                    w('  scan err:', repr(e))
            break
    except Exception as e:
        if i == 13: w('connect failed:', repr(e))
w('DONE')
log.close()
