(library (Compiler introduce-procedure-primitives)
	(export introduce-procedure-primitives)
	(import 
	  ;; Load Chez Scheme primitives:
	  (chezscheme)
	  ;; Load provided compiler framework:
	  (Framework driver)
	  (Framework wrappers)
	  (Framework match)
	  (Framework helpers)
	  (Framework prims)
	  (Compiler helper))
	(define-who introduce-procedure-primitives
		(lambda (x)
			(define locate
				(lambda (x ls)
					(cond
						[(null? ls) #f]
						[(eq? x (car ls)) 0]
						[(locate x (cdr ls)) => add1]
						[else #f])))
			(define locate-fv
				(lambda (cpv)
					(lambda (x)
						(cond
							[(locate x (cdr cpv)) =>
							(lambda (i) `(procedure-ref ,(car cpv) ',i))]
							[else x]))))
			(define make-set!
				(lambda (x)
					(define make
						(lambda (x n)
							(match x
								[(,uvar ,label) '()]
								[(,uvar ,label ,x ,x* ...)
								(cons `(procedure-set! ,uvar ',n ,x)
									(make `(,uvar ,label ,x* ...) (add1 n)))])))
					(make x 0)))
			(define intro
				(lambda (bd)
					(lambda (x)
						(match x
							[(letrec ((,label* ,[(intro '(dummy)) -> lam*]) ...) ,[expr])
							`(letrec ([,label* ,lam*] ...) ,expr)]
							[(lambda (,x* ...)
								(bind-free (dummy) ,[(intro bd) -> expr]))
							`(lambda (,x* ...) ,expr)]
							[(lambda (,cp ,x* ...)
								(bind-free (,cp ,fv* ...) ,[(intro `(,cp ,@fv*)) -> expr]))
							`(lambda (,cp ,x* ...) ,expr)]
							[(let ([,uvar* ,[expr*]] ...) ,[expr])
							`(let ([,uvar* ,expr*] ...) ,expr)]
							[(begin ,[e*] ...) `(begin ,e* ...)]
							[(if ,[t] ,[c] ,[a]) `(if ,t ,c ,a)]
							[(quote ,imm) `(quote ,imm)]
							[(closures ([,uvar* ,label* ,[fv*] ...] ...) ,[expr])
							(let ([length* (map length fv*)])
								`(let ([,uvar* (make-procedure ,label* ',length*)] ...)
									(begin
										,(map make-set! `([,uvar* ,label* ,fv* ...] ...)) ... ...
										,expr)))]
							[(,f ,[x*] ...) (guard (or (prim? f) (label? f)))
							`(,f ,x* ...)]
							[(,[f] ,[f],[x*] ...)
							`((procedure-code ,f) ,f ,x* ...)]
							[,x ((locate-fv bd) x)]))))
((intro '(dummy)) x)))
 );end library