import sys, time, subprocess
from pywinauto import Application

LOG = r'C:\Users\jacob\winstock-test2.log'
log = open(LOG, 'w', encoding='utf-8')
def w(*a):
    m = ' '.join(str(x) for x in a)
    print(m); log.write(m + '\n'); log.flush()

w('start')
p = subprocess.Popen([r'C:\Weisoft Stock(x64)\WinStock.exe'], cwd=r'C:\Weisoft Stock(x64)')
w('launched', p.pid)
time.sleep(25)
try:
    app = Application(backend='uia').connect(path=r'C:\Weisoft Stock(x64)\WinStock.exe', timeout=10)
    for win in app.windows():
        t = win.window_text() or ''
        w('WIN:', repr(t[:90]), '| cls:', win.class_name())
        if '无法创建' in t or '服务进程' in t:
            w('  -> error dialog found, clicking 确定...')
            try:
                ok = win.child_window(title='确定', control_type='Button')
                ok.click()
                w('  clicked 确定')
            except Exception as e:
                w('  click err:', repr(e))
            time.sleep(10)
            w('  after dismiss:')
            for win2 in app.windows():
                w('    WIN:', repr((win2.window_text() or '')[:90]), '| cls:', win2.class_name())
except Exception as e:
    w('connect failed:', repr(e))
w('DONE')
log.close()
