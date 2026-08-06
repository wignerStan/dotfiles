import os
import sys, time, subprocess
from pywinauto import Application

LOG = os.path.join(os.environ['USERPROFILE'], 'winstock-auto.log')
log = open(LOG, 'w', encoding='utf-8')
def w(*a):
    m = ' '.join(str(x) for x in a)
    print(m); log.write(m + '\n'); log.flush()

w('start, python:', sys.version.split()[0], '| elevated:', bool(subprocess.check_output('net session', shell=True, stderr=subprocess.DEVNULL) if True else b''))
try:
    p = subprocess.Popen([r'C:\Weisoft Stock(x64)\WinStock.exe'], cwd=r'C:\Weisoft Stock(x64)')
    w('WinStock launched, pid', p.pid)
except Exception as e:
    w('launch error:', repr(e))

for i in range(12):
    time.sleep(5)
    try:
        app = Application(backend='uia').connect(path=r'C:\Weisoft Stock(x64)\WinStock.exe', timeout=3)
        wins = app.windows()
        w('connected at t=%ds, windows: %d' % (5*(i+1), len(wins)))
        for win in wins[:6]:
            w('  window:', repr(win.window_text()[:100]), '| cls:', win.class_name())
        if wins:
            for win in wins[:2]:
                try:
                    for c in win.descendants(control_type='Button')[:15]:
                        tt = c.window_text()
                        if tt: w('    btn:', repr(tt))
                    for c in win.descendants(control_type='Edit')[:8]:
                        tt = c.window_text()
                        if tt: w('    edit:', repr(tt))
                except Exception as e:
                    w('  scan error:', repr(e))
            break
    except Exception as e:
        if i == 11:
            w('connect failed after 60s:', repr(e))
w('DONE')
log.close()
