(lang dune 3.4)
(name hello)
(license MIT-0)

; https://dune.readthedocs.io/en/stable/opam.html#generating-opam-files
(generate_opam_files true)

(cram enable)

; https://dune.readthedocs.io/en/stable/concepts.html#package-specification
(package
 (name hello)
 (synopsis "Friendly greetings"))
