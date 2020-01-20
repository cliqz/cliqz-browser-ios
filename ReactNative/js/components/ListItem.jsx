/* eslint-disable react/prop-types */
import React from 'react';
import { View, Text, TouchableWithoutFeedback } from 'react-native';
import { parse } from 'tldts';
import Logo from './Logo';
import { useStyles } from '../contexts/theme';

const getStyle = theme => ({
  row: {
    flexDirection: 'row',
  },
  firstRow: {
    flexDirection: 'row',
  },
  label: {
    color: theme.redColor,
    fontSize: 12,
    top: 1,
    left: 5,
  },
  rowText: {
    color: theme.textColor,
    marginLeft: 10,
    flex: 1,
    justifyContent: 'center',
  },
  rowTitle: {
    color: `${theme.textColor}99`,
  },
  rowDescription: {
    color: theme.textColor,
    fontSize: 13,
    fontWeight: 'bold',
  },
});

export default function ListItem({ url, title, onPress, label }) {
  const styles = useStyles(getStyle);

  const name = parse(url).hostname;

  /* eslint-disable prettier/prettier */
  return (
    <TouchableWithoutFeedback
      onPress={onPress}
    >
      <View style={styles.row}>
        <Logo url={url} size={48} />
        <View style={styles.rowText}>
          <View style={styles.firstRow}>
            <Text style={styles.rowTitle} allowFontScaling={false}>{name}</Text>
            {label &&
              <Text style={styles.label} allowFontScaling={false}>{label}</Text>
            }
          </View>
          <Text
            numberOfLines={2}
            style={styles.rowDescription}
            allowFontScaling={false}
          >{title}</Text>
        </View>
      </View>
    </TouchableWithoutFeedback>
  );
  /* eslint-enable prettier/prettier */
}
