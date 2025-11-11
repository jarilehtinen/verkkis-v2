module Verkkis
    module FuzzySearch
        extend self

        # Public: return products sorted by fuzzy relevance for the query
        def search_products(products, query)
            normalized_query = normalize(query)
            return [] if normalized_query.empty?

            scored = products.map do |product|
                name = product['name'].to_s
                normalized_name = normalize(name)
                score = score_pair(normalized_query, normalized_name)
                [product, score]
            end

            positive = scored.select { |(_, score)| score.positive? }
            ranked = positive.empty? ? scored : positive
            ranked.sort_by { |(_, score)| -score }.map(&:first)
        end

        private

        def normalize(text)
            text.to_s.downcase.gsub(/[^a-z0-9äöå\s]/i, " ").gsub(/\s+/, " ").strip
        end

        def score_pair(query, candidate)
            return 0 if query.empty? || candidate.empty?

            tokens = query.split
            candidate_tokens = candidate.split

            score = 0

            string_index = candidate.index(query)
            if string_index
                score += 600
                score += [200 - string_index, 0].max
            end

            matched_tokens = 0
            tokens.each_with_index do |token, index|
                next if token.empty?

                token_score = score_token(token, candidate, candidate_tokens)
                next if token_score <= 0

                matched_tokens += 1
                token_score += 60 if index.zero? && candidate.start_with?(token)
                score += token_score
            end

            coverage_ratio = tokens.empty? ? 0 : (matched_tokens.to_f / tokens.length)
            score += (coverage_ratio * 200)

            score += 80 if tokens_in_order?(tokens, candidate)

            condensed_query = query.delete(" ")
            condensed_candidate = candidate.delete(" ")
            score += (similarity_ratio(condensed_query, condensed_candidate) * 120).round

            score
        end

        def score_token(token, candidate, candidate_tokens)
            if (idx = candidate.index(token))
                return 200 - [idx, 150].min
            end

            best_distance = candidate_tokens.map { |cand| levenshtein(token, cand) }.min
            return 0 unless best_distance

            threshold = [2, (token.length / 3.0).ceil].max
            return 0 if best_distance > threshold

            140 - best_distance * 30
        end

        def tokens_in_order?(tokens, candidate)
            return false if tokens.empty?

            position = 0
            tokens.each do |token|
                next if token.empty?
                idx = candidate.index(token, position)
                return false unless idx
                position = idx + token.length
            end
            true
        end

        def similarity_ratio(left, right)
            max_len = [left.length, right.length].max
            return 0.0 if max_len.zero?

            distance = levenshtein(left, right)
            [(max_len - distance).to_f / max_len, 0.0].max
        end

        def levenshtein(str1, str2)
            m = str1.length
            n = str2.length
            return n if m.zero?
            return m if n.zero?

            previous_row = (0..n).to_a
            current_row = Array.new(n + 1)

            (1..m).each do |i|
                current_row[0] = i
                c1 = str1[i - 1]
                (1..n).each do |j|
                    cost = c1 == str2[j - 1] ? 0 : 1
                    current_row[j] = [
                        current_row[j - 1] + 1,
                        previous_row[j] + 1,
                        previous_row[j - 1] + cost
                    ].min
                end
                previous_row, current_row = current_row, previous_row
            end

            previous_row[n]
        end
    end
end
