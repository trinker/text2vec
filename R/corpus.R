#' @name create_vocab_corpus
#' @title RAM-friendly streaming corpus construction.
#' @description This functions allow to create corpus objects (vocabulary or hash based),
#' which are stored outside of R's heap and wrapped via Reference Classes using Rcpp-Modules.
#' From that objects you can easily extract Document-Term (dtm) and Term-Cooccurnce(tcm)
#' matrices. Also text2vec grows corpus for \code{tcm} and \code{dtm} simultaneously in a very
#' ram-friendly and efficient way using iterators abstraction. So you can build corpuses from
#' objects/files which are orders of magnitude larger that available RAM.
#' @param iterator iterator over \code{list} of \code{character} vectors.
#' Each element is a list of tokens = tokenized and normalized strings.
#' @param vocabulary \code{text2vec_vocabulary} object, see \link{vocabulary}.
#' @param grow_dtm \code{logical} should we grow Document-Term matrix
#' during corpus construction or not.
#' @param skip_grams_window \code{integer} window for Term-Cooccurence matrix
#' construction. 0L points to do not construct such matrix.
#' @return corpus object,
#' We can add documents into this corpus by reference - no copy at all.
#' See source code for details.
#' For full process example see \link{get_dtm}.
#' @export
create_vocab_corpus <- function(iterator,
                                vocabulary,
                                grow_dtm = TRUE,
                                skip_grams_window = 0L) {
  if (!grow_dtm && skip_grams_window == 0L)
    stop("At least one of the arguments 'grow_dtm', 'skip_grams_window' should
         satisfy grow_dtm == TRUE or skip_grams_window > 0")

  if (!inherits(iterator, 'iter'))
    stop("iterator argument should be iterator over list of tokens (class 'iter')")

  vocab_corpus <- new(VocabCorpus,
                      vocab = vocabulary$vocab$terms,
                      ngram_min = vocabulary$ngram[["ngram_min"]],
                      ngram_max = vocabulary$ngram[["ngram_max"]],
                      window_size = skip_grams_window)
  attr(vocab_corpus, 'ids') <- character(0)
  corpus_insert(vocab_corpus, iterator)
}

#' @rdname create_vocab_corpus
#' @param feature_hasher \code{text2vec_feature_hasher} object, which contains meta information
#' about feature hashing. See \link{feature_hasher} for details.
#' @seealso \link{feature_hasher}.
#' @export
create_hash_corpus <- function(iterator,
                               feature_hasher = feature_hasher(),
                               grow_dtm = TRUE,
                               skip_grams_window = 0) {

  if (!inherits(iterator, 'iter'))
    stop("iterator argument should be iterator over list of tokens (class 'iter')")

  hash_corpus <- new(HashCorpus,
                     hash_size = feature_hasher$hash_size,
                     ngram_min = feature_hasher$ngram[["ngram_min"]],
                     ngram_max = feature_hasher$ngram[["ngram_max"]],
                     window_size = skip_grams_window,
                     feature_hasher$signed_hash)
  attr(hash_corpus, 'ids') <- character(0)
  corpus_insert(hash_corpus, iterator)
}

corpus_insert <- function(corpus, iterator) {
  while (TRUE) {
    val <- try(nextElem(iterator), silent = T)
    if (class(val) == "try-error") {
      if (attributes(val)$condition$message == "StopIteration")
        break
      # handle other errors
      else
        stop(attributes(val)$condition$message)
    }
    corpus$insert_document_batch(val)
    attr(corpus, 'ids') <- c(attr(corpus, 'ids'), names(val))
  }
  corpus
}
