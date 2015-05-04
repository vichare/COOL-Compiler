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
SINGLE_OP       [\{\}\.\@\~\;\*\/\+\-\<\=\:\(\)\,\[\]]

%s  STRING COMMENT INLINECOMMENT


%%

 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */

<INITIAL>[ \t\v\f\r]	;

<INITIAL>class			{ return CLASS; }
<INITIAL>else			{ return ELSE; }
<INITIAL>fi			    { return FI; }
<INITIAL>if		    	{ return IF; }
<INITIAL>in		    	{ return IN; }
<INITIAL>inherits    	{ return INHERITS; }
<INITIAL>let 			{ return LET; }
<INITIAL>loop			{ return LOOP; }
<INITIAL>pool			{ return POOL; }
<INITIAL>then  			{ return THEN; }
<INITIAL>while  		{ return WHILE; }
<INITIAL>case  			{ return CASE; }
<INITIAL>esac  			{ return ESAC; }
<INITIAL>of  			{ return OF; }
<INITIAL>{DARROW}		{ return (DARROW); }
<INITIAL>new  			{ return NEW; }
<INITIAL>isvoid         { return ISVOID; }
<INITIAL>{ASSIGNMENT}   { return ASSIGN; }
<INITIAL>not            { return NOT; }
<INITIAL>{LESSEQ}       { return LE; }
<INITIAL>{SINGLE_OP}    { return yytext[0]; }

<INITIAL,COMMENT>{NEWLINE}		{ ++curr_lineno; }
<INITIAL><<EOF>>		yyterminate();

  /*--------- Comment ---------------*/
<INITIAL>\(\*         BEGIN(COMMENT);
<COMMENT><<EOF>>  { cool_yylval.error_msg = "Unterminated string constant";
                    return ERROR; }
<COMMENT>\*\)         BEGIN(INITIAL);
<COMMENT>.          ;

<INITIAL>\-\-        BEGIN(INLINECOMMENT);
<INLINECOMMENT>\n    BEGIN(INITIAL);
<INLINECOMMENT>.     ;

  /*--------- String ---------------*/

<INITIAL>\"       { BEGIN(STRING); }

<STRING>[^\\\n\0\"] { yymore();}

<STRING>\\\n      { ++curr_lineno;
                    yymore();}
<STRING>\\[^\0]   { yymore(); }
<STRING>\\\0        |
<STRING>\0        { cool_yylval.error_msg = "String contains null character";
                    BEGIN(INITIAL);
                    return ERROR; }
<STRING><<EOF>>   { cool_yylval.error_msg = "EOF in string constant";
                    BEGIN(INITIAL);
                    return ERROR; }

<STRING>\n        { ++curr_lineno;
                    cool_yylval.error_msg = "Unterminated string constant";
                    BEGIN(INITIAL);
                    return ERROR; }

<STRING>\"         { // TODO : escape the string
                    cool_yylval.symbol = stringtable.add_string(yytext, yyleng - 1);
                    BEGIN(INITIAL);
                    return STR_CONST; }


  /*--------- Int ---------------*/

<INITIAL>[0-9]+   { cool_yylval.symbol = inttable.add_string(yytext, yyleng);
                    return INT_CONST; }

  /*--------- Bool --------------*/

<INITIAL>true     { cool_yylval.boolean = true;
                  return BOOL_CONST; }
<INITIAL>false    { cool_yylval.boolean = false;
                  return BOOL_CONST; }

<INITIAL>{TID}    { cool_yylval.symbol = idtable.add_string(yytext, yyleng); 
                  return TYPEID; }
<INITIAL>{OID}    { cool_yylval.symbol = idtable.add_string(yytext, yyleng); 
                  return OBJECTID; }


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
