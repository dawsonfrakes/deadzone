// 2>/dev/null; g++ $0 && ./a.out; exit
// Dawson, 10/18/22:
//  I haven't used C++ in roughly 4 years.
//  Andreas Kling made me think I should try it out again.
//  I'm going to attempt to implement the interpreter described at https://ruslanspivak.com/lsbasi-part1.
//  In theory this is step 1 to learning what I do and don't want in my system.

#include <algorithm>
#include <iostream>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

enum TokenType {
    id,
    plus,
    minus,
    mul,
    div_integer,
    div_float,
    integer,
    lparen,
    rparen
};

const char *TokenTypeString[] = {
    "ID",
    "Plus",
    "Minus",
    "Mul",
    "DivInteger",
    "DivFloat",
    "Integer",
    "LParen",
    "RParen"
};

struct Token {
    TokenType type;
    std::optional<std::string> data = std::nullopt;
};

static const std::unordered_map<std::string, Token> keywords = {
    {"div", {div_integer}}
};

std::vector<Token> tokenize(std::string input)
{
    const size_t length = input.length();
    std::vector<Token> result;
    size_t pos = 0;
    while (pos < length) {
        // skip whitespace
        if (std::isspace(input[pos])) {
            ++pos;
            continue;
        }
        // integers
        if (std::isdigit(input[pos])) {
            size_t read = 0;
            result.push_back({integer, std::to_string(std::stoi(input.substr(pos), &read))});
            pos += read;
            continue;
        }
        // identifers / keywords
        if (std::isalpha(input[pos]) or input[pos] == '_') {
            char c;
            size_t i = 0;
            while (pos+i < length and (c = input.at(pos+i++)))
                if (!(std::isalnum(c) or c == '_')) break;

            std::string word = input.substr(pos, i - 1);
            std::transform(word.begin(), word.end(), word.begin(), [](unsigned char c){ return std::tolower(c); });
            if (keywords.count(word)) {
                result.push_back(keywords.at(word));
            } else {
                result.push_back({id, word});
            }

            pos += i;
            continue;
        }
        // operators
        switch (input[pos]) {
            case '+': {
                result.push_back({plus});
                ++pos;
            } continue;
            case '-': {
                result.push_back({minus});
                ++pos;
            } continue;
            case '*': {
                result.push_back({mul});
                ++pos;
            } continue;
            case '(': {
                result.push_back({lparen});
                ++pos;
            } continue;
            case ')': {
                result.push_back({rparen});
                ++pos;
            } continue;
            // case '/': {
            //     result.push_back({div_float});
            //     ++pos;
            // } continue;
        }
        throw std::runtime_error(std::string("Symbol '") + input[pos] + "' not eligible for tokenization");
    }
    return result;
}

// typedef'd so I can decide which type of value is returned in the future
typedef int IntResult;

// expect tokens to be in a specific order for things to work correctly
struct Parser {
    // TODO: switch to using a std::vector<Token>::iterator instead of an index and a reference
    const std::vector<Token>& tokens;
    size_t current_token = 0;

    void eat(TokenType expect) {
        if (current_token >= tokens.size())
            throw std::runtime_error(std::string(TokenTypeString[expect]) + " expected and not found. I ran out of input!");
        if (tokens[current_token].type != expect)
            throw std::runtime_error(std::string(TokenTypeString[tokens[current_token].type]) + " != " + TokenTypeString[expect]);
        ++current_token;
    }

    IntResult factor() {
        const size_t token = current_token;
        if (tokens[token].type == integer) {
            eat(integer);
            return std::stoi(tokens[token].data.value());
        }

        eat(lparen);
        const IntResult result = expr();
        eat(rparen);
        return result;
    }

    IntResult term() {
        IntResult result = factor();
        while (true) {
            switch (tokens[current_token].type) {
                case mul: eat(mul); result *= factor(); continue;
                case div_integer: eat(div_integer); result /= factor(); continue;
            }
            break;
        }

        return result;
    }

    IntResult expr() {
        IntResult result = term();
        while (true) {
            switch (tokens[current_token].type) {
                case plus: eat(plus); result += term(); continue;
                case minus: eat(minus); result -= term(); continue;
            }
            break;
        }

        return result;
    }
};

int main()
{
    std::vector<Token> tokens = tokenize("7 - 8 div 4");
    Parser parser = {tokens};
    std::cout << "Parser result: " << parser.expr() << std::endl;
    std::cout << "Tokenizer result:" << std::endl;
    for (const Token& t : tokens) {
        std::cout << "\tType: " << TokenTypeString[t.type] << (t.data ? "; Data: \"" : "") << t.data.value_or("") << (t.data ? "\"" : "") << std::endl;
    }
}
