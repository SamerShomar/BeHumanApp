from pathlib import Path
path = Path('lib/features/home/presentation/screens/home_screen.dart')
text = path.read_text('utf-8', errors='replace')
lines = text.splitlines()
for idx, line in enumerate(lines):
    if "proposal['date']" in line and "proposal['amount']" in line:
        lines[idx] = '                                        "${proposal[\'date\']} • ${proposal[\'amount\']}\\$",'
        break
else:
    raise SystemExit('Target line not found')
path.write_text('\n'.join(lines) + '\n', 'utf-8')
print('fixed')
