/* eslint-disable react/prop-types */
import React from 'react';
import {
  StyleSheet,
  View,
  Text,
  ScrollView,
  TouchableWithoutFeedback,
  NativeModules,
} from 'react-native';
import NativeDrawable from '../../../components/NativeDrawable';
import ResultList from './ResultList';
import { withTheme } from '../../../contexts/theme';
import CliqzProvider from '../../../contexts/cliqz';
import t from '../../../services/i18n';

const getStyles = theme =>
  StyleSheet.create({
    container: {
      flex: 1,
      flexDirection: 'column',
    },
    searchUI: {
      paddingTop: 20,
      backgroundColor: theme.backgroundColor,
    },
    bouncer: {
      backgroundColor: theme.backgroundColor,
      height: 500,
      position: 'absolute',
      top: -500,
      left: 0,
      right: 0,
    },
    separator: {
      height: 1,
      backgroundColor: theme.separatorColor,
    },
    footer: {
      height: 50,
      borderTopColor: theme.separatorColor,
      borderTopWidth: 1,
      backgroundColor: theme.backgroundColor,
      alignItems: 'center',
      justifyContent: 'center',
      borderBottomLeftRadius: 10,
      borderBottomRightRadius: 10,
    },
    footerText: {
      color: theme.textColor,
      fontSize: 9,
    },
    noResults: {
      backgroundColor: theme.backgroundColor,
      paddingTop: 24,
      paddingBottom: 24,
      alignItems: 'center',
      justifyContent: 'center',
    },
    noResultsText: {
      color: theme.textColor,
      fontSize: 14,
    },
    searchEnginesHeader: {
      alignItems: 'center',
      justifyContent: 'center',
      marginTop: 30,
    },
    searchEnginesHeaderText: {
      color: 'white',
      fontSize: 12,
    },
    searchEnginesContainer: {
      flexDirection: 'row',
      justifyContent: 'space-evenly',
      marginTop: 10,
      marginBottom: 100,
      textAlign: 'center',
    },
    searchEngineIcon: {
      height: 74,
      width: 74,
      borderRadius: 10,
      overflow: 'hidden',
    },
    searchEngineText: {
      color: 'white',
      textAlign: 'center',
      fontSize: 12,
    },
    cardListStyle: {
      paddingLeft: 0,
      paddingRight: 0,
    },
  });

const BLOCKED_TEMPLATES = ['calculator', 'currency', 'flight'];

function isResultAllowed({ template, provider, type }) {
  return (
    !BLOCKED_TEMPLATES.includes(template) &&
    type !== 'navigate-to' &&
    Boolean(provider) &&
    provider !== 'instant' &&
    provider !== 'rich-header' // promises sometimes arrive to ui
  );
}

class Results extends React.Component {
  constructor(props) {
    super(props);
    this.scrollRef = React.createRef();
  }

  // eslint-disable-next-line react/no-deprecated
  componentWillReceiveProps(/* { results, query } */) {
    if (this.scrollRef.current) {
      this.scrollRef.current.scrollTo({ y: 0, animated: false });
    }
  }

  openSearchEngineLink = async (url, index, name) => {
    const { results = {}, query, cliqz } = this.props;
    const meta = results.meta || {};
    await cliqz.mobileCards.openLink(url, {
      action: 'click',
      elementName: 'icon',
      isFromAutoCompletedUrl: false,
      isNewTab: false,
      isPrivateMode: false,
      isPrivateResult: meta.isPrivate,
      query,
      isSearchEngine: true,
      rawResult: {
        index,
        url,
        provider: 'instant',
        type: 'supplementary-search',
        kind: [`custom-search|{"class":"${name}"}`],
      },
      resultOrder: meta.resultOrder,
      url,
    });
  };

  render() {
    const { results: _results, query, theme: _theme, cliqz } = this.props;
    const {
      results: allResults,
      suggestions,
      meta,
      query: resultsQuery,
    } = _results;
    const results = (allResults || []).filter(isResultAllowed);
    const styles = getStyles(_theme);

    NativeModules.BrowserActions.showQuerySuggestions(
      resultsQuery,
      suggestions,
    );

    if (results[0]) {
      const { friendlyUrl, text } = results[0];
      if (friendlyUrl && text) {
        cliqz.mobileCards.handleAutocompletion(friendlyUrl, text);
      }
    }

    return (
      <View style={styles.container}>
        <CliqzProvider.Provider value={cliqz}>
          <ScrollView
            bounces
            ref={this.scrollRef}
            showsVerticalScrollIndicator={false}
            keyboardDismissMode="on-drag"
            keyboardShouldPersistTaps="handled"
            onTouchStart={() => cliqz.mobileCards.hideKeyboard()}
            onScrollEndDrag={() => cliqz.search.reportHighlight()}
          >
            <View style={styles.bouncer} />
            <View
              accessible={false}
              accessibilityLabel="search-results"
              style={styles.searchUI}
            >
              <ResultList
                results={results}
                meta={meta}
                style={styles.cardListStyle}
                header={<View />}
                separator={<View style={styles.separator} />}
                footer={<View />}
              />
            </View>
            <>
              {results.length === 0 && (
                <View style={styles.noResults}>
                  <Text style={styles.noResultsText}>
                    {t('search_no_results')}
                  </Text>
                </View>
              )}
              <View style={styles.footer}>
                <Text style={styles.footerText}>{t('search_footer')}</Text>
              </View>
              <View style={styles.searchEnginesHeader}>
                <Text style={styles.searchEnginesHeaderText}>
                  {t('search_alternative_search_engines_info')}
                </Text>
              </View>
              <View style={styles.searchEnginesContainer}>
                <TouchableWithoutFeedback
                  onPress={() =>
                    this.openSearchEngineLink(
                      `https://beta.cliqz.com/search?q=${encodeURIComponent(
                        query,
                      )}#channel=ios`,
                      0,
                      'cliqz',
                    )
                  }
                >
                  <View>
                    <NativeDrawable
                      style={styles.searchEngineIcon}
                      color="#ffffff"
                      source="ic_ez_cliqz"
                    />
                    <Text style={styles.searchEngineText}>Cliqz</Text>
                  </View>
                </TouchableWithoutFeedback>
                <TouchableWithoutFeedback
                  onPress={() =>
                    this.openSearchEngineLink(
                      `https://www.google.com/search?q=${encodeURIComponent(
                        query,
                      )}`,
                      1,
                      'google',
                    )
                  }
                >
                  <View>
                    <NativeDrawable
                      style={styles.searchEngineIcon}
                      color="#ffffff"
                      source="ic_ez_google"
                    />
                    <Text style={styles.searchEngineText}>Google</Text>
                  </View>
                </TouchableWithoutFeedback>
                <TouchableWithoutFeedback
                  onPress={() =>
                    this.openSearchEngineLink(
                      `https://duckduckgo.com/?q=${encodeURIComponent(query)}`,
                      2,
                      'duckduckgo',
                    )
                  }
                >
                  <View>
                    <NativeDrawable
                      style={styles.searchEngineIcon}
                      color="#ffffff"
                      source="ic_ez_ddg"
                    />
                    <Text style={styles.searchEngineText}>DuckDuckGo</Text>
                  </View>
                </TouchableWithoutFeedback>
              </View>
            </>
          </ScrollView>
        </CliqzProvider.Provider>
      </View>
    );
  }
}

export default withTheme(Results);
