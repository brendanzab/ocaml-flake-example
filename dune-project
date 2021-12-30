(lang dune 2.9)
(name hello)

(generate_opam_files true)

(cram enable)

; https://dune.readthedocs.io/en/stable/concepts.html#package-specification
(package
 (name hello)
 (synopsis "Friendly greetings"))
