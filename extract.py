import json, re

out = open('lost_methods.dart', 'w', encoding='utf-8')
content = open(r'C:\Users\seanm\.gemini\antigravity-ide\brain\dd90ffb3-6745-48d8-99d2-844054c41759\.system_generated\logs\transcript_full.jsonl', encoding='utf-8').read()

pattern = re.compile(r'"ReplacementContent":"(.*?)"', re.DOTALL)
matches = pattern.findall(content)

for m in matches:
    if 'checkStoreDelivery' in m or 'getStoreAddons' in m or 'checkoutCustomTicket' in m or 'createCustomTicket' in m:
        try:
            val = json.loads('"' + m + '"')
            out.write(val + '\n\n')
        except Exception as e:
            pass

out.close()
