import json
import os
import random
import gzip

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, 'scripts', 'out', 'quiz_books')

def get_book(bid):
    path = os.path.join(CACHE, bid + '.json')
    raw = open(path, 'rb').read()
    if raw[:2] == b'\x1f\x8b':
        raw = gzip.decompress(raw)
    return json.loads(raw)

def main():
    bid = 'al_bidaya_wan_nihaya'
    path = os.path.join(CACHE, bid + '.json')
    if not os.path.exists(path):
        print("Run build_history_quiz.py first to cache books.")
        return
    book = get_book(bid)
    
    questions = []
    
    # We need 731 questions. We will iterate through pages and pick paragraphs.
    random.seed(42) # For reproducibility
    
    for pi, page in enumerate(book['pages']):
        p = page['p']
        # Get paragraphs that have enough words
        paras = [para['t'] for para in page['paras'] if isinstance(para, dict) and 't' in para and len(para['t'].split()) > 20]
        
        if not paras:
            continue
            
        para = random.choice(paras)
        words = para.split()
        
        # Pick a starting index for our 8-word quote
        start = random.randint(0, len(words) - 10)
        quote_words = words[start:start+8]
        quote = ' '.join(quote_words)
        
        # Pick a word to blank out (must be a substantial word, length > 3)
        valid_blanks = [i for i, w in enumerate(quote_words) if len(w) > 3]
        if not valid_blanks:
            continue
        
        blank_idx = random.choice(valid_blanks)
        answer = quote_words[blank_idx]
        
        # Blank it out in the question
        q_words = list(quote_words)
        q_words[blank_idx] = "..."
        q = "أكمل العبارة: " + ' '.join(q_words)
        
        # Generate 3 dummy choices based on random words from the paragraph
        choices = [answer]
        attempts = 0
        while len(choices) < 4 and attempts < 100:
            attempts += 1
            w = random.choice(words)
            if len(w) > 3 and w not in choices:
                choices.append(w)
                
        if len(choices) < 4:
            continue
            
        questions.append({
            "book": bid,
            "pageIndex": pi,
            "p": p,
            "level": "l3",
            "q": q,
            "choices": choices,
            "quote": quote,
            "explain": quote
        })
        
        if len(questions) >= 731:
            break
            
    print(f"Total questions generated: {len(questions)}")
    
    out_path = os.path.join(ROOT, 'scripts', 'quiz', 'q_auto.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(questions, f, ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main()
