import json

def format_ids():
    with open('shamela_search_results.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    with open('ids.txt', 'w', encoding='utf-8') as f:
        for d in data:
            f.write(f"{d['id']} - {d['name']}\n")

if __name__ == '__main__':
    format_ids()
