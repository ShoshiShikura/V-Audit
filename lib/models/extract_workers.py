import openpyxl
import json

# Load the workbook and select the active worksheet
wb = openpyxl.load_workbook('tm_audit/lib/export_20250716131000 - Copy.xlsx')
ws = wb.active

workers = []
for row in ws.iter_rows(min_row=2):
    user_id = row[1].value
    company = row[4].value
    name = row[6].value
    action = row[11].value
    if action == 'HIRING' and user_id and name and company:
        workers.append({
            'userId': user_id,
            'name': name,
            'companies': [company],
            'status': 'active',
            'ic': ''
        })

with open('tm_audit/lib/models/preset_workers.json', 'w', encoding='utf-8') as f:
    json.dump(workers, f, ensure_ascii=False, indent=2) 