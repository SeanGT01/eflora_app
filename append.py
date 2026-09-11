lines = open('lost_methods.dart', encoding='utf-8').read().split('\n')
methods = '\n'.join(lines[22:214])

with open(r'C:\Users\seanm\OneDrive\Desktop\eflowers_app\lib\services\chat_service.dart', 'r', encoding='utf-8') as f:
    chat_content = f.read()

chat_content = chat_content.rstrip()
if chat_content.endswith('}'):
    chat_content = chat_content[:-1] + '\n' + methods + '\n}'

with open(r'C:\Users\seanm\OneDrive\Desktop\eflowers_app\lib\services\chat_service.dart', 'w', encoding='utf-8') as f:
    f.write(chat_content)
