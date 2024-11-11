(lang dune 3.8)
(name hello)
(license MIT-0)

; https://dune.readthedocs.io/en/stable/opam.html#generating-opam-files
(generate_opam_files)
(opam_file_location inside_opam_directory)

(cram enable)

; https://dune.readthedocs.io/en/stable/concepts.html#package-specification
(package
 (name hello)
 (synopsis "Friendly greetings"))
