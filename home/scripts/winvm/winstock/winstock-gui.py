import os
import sys, time, subprocess
from pywinauto import Application

LOG = os.path.join(os.environ['USERPROFILE'], 'winstock-gui.log')
log = open(LOG, 'w', encoding='utf-8')
def w(*a):
    m = ' '.join(str(x) for x in a)
    print(m); log.write(m + '\n'); log.flush()

p = subprocess.Popen([r'C:\Weisoft Stock(x64)\WinStock.exe'], cwd=r'C:\Weisoft Stock(x64)')
w('launched, pid', p.pid)
for i in range(12):
    time.sleep(5)
    try:
        app = Application(backend='uia').connect(path=r'C:\Weisoft Stock(x64)\WinStock.exe', timeout=3)
        wins = app.windows()
        w('t=%ds windows: %d' % (5*(i+1), len(wins)))
        for win in wins[:6]:
            w('  window:', repr(win.window_text()[:100]), '| cls:', win.class_name())
        if wins:
            # check no error dialog
            bad = [w_ for w_ in wins if '无法创建' in (w_.window_text() or '')]
            w('error dialog present:', bool(bad))
            break
    except Exception as e:
        if i == 11: w('connect failed:', repr(e))
w('DONE')
log.close()
