import os
import sys, time, subprocess
from pywinauto import Application

LOG = os.path.join(os.environ['USERPROFILE'], 'winstock-watch.log')
log = open(LOG, 'w', encoding='utf-8')
def w(*a):
    m = ' '.join(str(x) for x in a)
    print(m); log.write(m + '\n'); log.flush()

def procs():
    out = subprocess.run(['tasklist', '/fo', 'csv', '/nh'], capture_output=True, text=True).stdout
    return {p.split('","')[0].strip('"') for p in out.splitlines() if p}

before = procs()
w('baseline processes:', len(before))
p = subprocess.Popen([r'C:\Weisoft Stock(x64)\WinStock.exe'], cwd=r'C:\Weisoft Stock(x64)')
w('WinStock launched, pid', p.pid)
time.sleep(3)
for i in range(10):
    now = procs()
    new = now - before
    if new:
        for n in sorted(new):
            w('  t+%ds new process: %s' % (3*(i+1), n))
    time.sleep(3)
w('scan done')
# grab the dialog text if present
try:
    app = Application(backend='uia').connect(path=r'C:\Weisoft Stock(x64)\WinStock.exe', timeout=5)
    for win in app.windows():
        w('window:', repr(win.window_text()), '| cls:', win.class_name())
except Exception as e:
    w('connect err:', repr(e))
w('DONE')
log.close()
