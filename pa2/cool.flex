/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

size_t unescape(char* text, size_t len) {
    size_t src = 0;
    size_t dst = 0;
    while (src < len) {
        if (text[src] != '\\') {
            if (src != dst) {
                text[dst] = text[src];
            }
        } else {
            ++src;
            switch(text[src]) {
                case 'b': text[dst] = '\b'; break;
                case 't': text[dst] = '\t'; break;
                case 'n': text[dst] = '\n'; break;
                case 'f': text[dst] = '\f'; break;
                default : text[dst] = text[src];
            }
        }
        ++src;
        ++dst;
    }
    return dst;
}

int comment_nest = 0;
bool str_error_flag;

#define _printf NULL;

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ASSIGNMENT      <-
LESSEQ          <=
NEWLINE		    \n
TID         	[A-Z][A-Za-z0-9_]*
OID         	[a-z][A-Za-z0-9_]*
SINGLE_OP       [\{\}\.\@\~\;\*\/\+\-\<\=\:\(\)\,]

%s  STRING COMMENT INLINECOMMENT END


%%

 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */

<INITIAL>[ \t\v\f\r]	;

<INITIAL>[Cc][Ll][Aa][Ss][Ss]	{ return CLASS; }
<INITIAL>[Ee][Ll][Ss][Ee]       { return ELSE; }
<INITIAL>[Ff][Ii]               { return FI; }
<INITIAL>[Ii][Ff]		    	{ return IF; }
<INITIAL>[Ii][Nn]    	    	{ return IN; }
<INITIAL>[Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]    	{ return INHERITS; }
<INITIAL>[Ll][Ee][Tt] 			{ return LET; }
<INITIAL>[Ll][Oo][Oo][Pp]    	{ return LOOP; }
<INITIAL>[Pp][Oo][Oo][Ll]    	{ return POOL; }
<INITIAL>[Tt][Hh][Ee][Nn]    	{ return THEN; }
<INITIAL>[Ww][Hh][Ii][Ll][Ee]   { return WHILE; }
<INITIAL>[Cc][Aa][Ss][Ee]   	{ return CASE; }
<INITIAL>[Ee][Ss][Aa][Cc]		{ return ESAC; }
<INITIAL>[Oo][Ff]    			{ return OF; }
<INITIAL>{DARROW}	        	{ return (DARROW); }
<INITIAL>[Nn][Ee][Ww]  			{ return NEW; }
<INITIAL>[Ii][Ss][Vv][Oo][Ii][Dd]         { return ISVOID; }
<INITIAL>{ASSIGNMENT}           { return ASSIGN; }
<INITIAL>[Nn][Oo][Tt]           { return NOT; }
<INITIAL>{LESSEQ}               { return LE; }
<INITIAL>{SINGLE_OP}            { return yytext[0]; }

<INITIAL,COMMENT>{NEWLINE}		{ ++curr_lineno; }
<INITIAL><<EOF>>		{ yyterminate(); }

  /*--------- Comment ---------------*/
<INITIAL>\(\*     { BEGIN(COMMENT);
                    comment_nest = 1; _printf("<(*>");}
<COMMENT><<EOF>>  { cool_yylval.error_msg = "EOF in comment";
                    BEGIN(END);
                    unput('.');
                    return ERROR;}
<COMMENT>\*\)     { if (--comment_nest <= 0) BEGIN(INITIAL); _printf("<*%d)>", comment_nest);}
<COMMENT>\(\*     { ++comment_nest; _printf("<(%d*>", comment_nest);}
<COMMENT>.          ;

<INITIAL>\-\-        BEGIN(INLINECOMMENT);
<INLINECOMMENT>\n  { BEGIN(INITIAL); ++curr_lineno; }
<INLINECOMMENT>.     ;
<INLINECOMMENT><<EOF>>     yyterminate();

  /*--------- String ---------------*/

<INITIAL>\"       { BEGIN(STRING); str_error_flag = false;}

<STRING>[^\\\n\0\"] { yymore();}

<STRING>\\\n      { ++curr_lineno;
                    yymore();}
<STRING>\\[^\0]   { yymore(); }
<STRING>\\\0      { if (!str_error_flag) {
                        cool_yylval.error_msg = "String contains escaped null character";
                        str_error_flag = true;
                        return ERROR; 
                    }
                  }
<STRING>\0        { if (!str_error_flag) { 
                        cool_yylval.error_msg = "String contains null character";
                        str_error_flag = true;
                        return ERROR; 
                    }
                  }
<STRING><<EOF>>   { if (!str_error_flag) {
                        cool_yylval.error_msg = "EOF in string constant";
                        str_error_flag = true;
                        BEGIN(END);
                        unput('.'); // use this trick to prevent fatal error
                        return ERROR; 
                    }
                  }

<STRING>\n        { ++curr_lineno;
                    cool_yylval.error_msg = "Unterminated string constant";
                    BEGIN(INITIAL);
                    if (!str_error_flag) return ERROR; }

<STRING>\"        { yyleng = unescape(yytext, yyleng);
                    cool_yylval.symbol = stringtable.add_string(yytext, --yyleng);
                    BEGIN(INITIAL);
                    if (!str_error_flag) {
                        if (yyleng <= 1024) {
                            return STR_CONST;
                        } else {
                            cool_yylval.error_msg = "String constant too long";
                            return ERROR;
                        }
                    }
                  }

<END>.               yyterminate();

  /*--------- Int ---------------*/

<INITIAL>[0-9]+   { cool_yylval.symbol = inttable.add_string(yytext, yyleng);
                    return INT_CONST; }

  /*--------- Bool --------------*/

<INITIAL>t[Rr][Uu][Ee] { cool_yylval.boolean = true;
                    return BOOL_CONST; }
<INITIAL>f[Aa][Ll][Ss][Ee] { cool_yylval.boolean = false;
                    return BOOL_CONST; }

<INITIAL>{TID}    { cool_yylval.symbol = idtable.add_string(yytext, yyleng); 
                    return TYPEID; }
<INITIAL>{OID}    { cool_yylval.symbol = idtable.add_string(yytext, yyleng); 
                    return OBJECTID; }

<INITIAL>\*\)     { cool_yylval.error_msg = "Unmatched *)";
                    return ERROR; }

<INITIAL>.        { cool_yylval.error_msg = yytext;
                    return ERROR; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


%%
